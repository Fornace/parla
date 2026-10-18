import Foundation
import Observation

/// What the debrief screen needs once a conversation has ended.
struct SessionDraft: Sendable {
    let room: Room
    let language: PracticeLanguage
    let level: Level
    let seconds: Int
    let lines: [LineRecord]
}

/// Runs one conversation: audio in, model, audio out, and the hand back.
@MainActor
@Observable
final class Conversation {
    enum Phase: Equatable {
        case preparing
        case speaking
        case listening
        case thinking
        case ended
        case failed(String)
    }

    let room: Room
    let language: PracticeLanguage
    let level: Level

    let listener = Listener()
    let speaker = Speaker()

    private let tutor: Tutor
    private var turnTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var startedAt: Date?
    private var deadline: Date?
    private var isFinishing = false
    private var lastUserLine = ""

    private(set) var phase: Phase = .preparing
    private(set) var lines: [LineRecord] = []
    private(set) var liveLine = ""
    private(set) var elapsed: TimeInterval = 0
    private(set) var turns = 0
    private(set) var draft: SessionDraft?

    /// The tutor closes the room after this many learner turns.
    var maximumTurns = 8

    init(room: Room, language: PracticeLanguage, level: Level) {
        self.room = room
        self.language = language
        self.level = level
        self.tutor = Tutor(room: room, language: language, level: level)
    }

    var remaining: TimeInterval {
        guard let deadline else { return TimeInterval(room.minutes * 60) }
        return max(0, deadline.timeIntervalSinceNow)
    }

    func start() {
        guard phase == .preparing, startedAt == nil else { return }
        turnTask = Task { await begin() }
    }

    private func begin() async {
        tutor.warmUp()
        do {
            try await listener.start(language: language)
        } catch {
            await fail(error)
            return
        }
        listener.onUtterance = { [weak self] text in
            self?.receive(text)
        }
        listener.setMuted(true)

        startedAt = .now
        deadline = Date.now.addingTimeInterval(TimeInterval(room.minutes * 60))
        startClock()

        do {
            phase = .speaking
            let opening = try await tutor.opening(onPartial: { [weak self] partial in
                self?.liveLine = partial
            })
            append(.init(order: lines.count, isYou: false, text: opening))
            liveLine = opening
            await speaker.say(opening, language: language)
            guard !isFinishing else { return }
            phase = .listening
            liveLine = ""
            listener.setMuted(false)
        } catch {
            await fail(error)
        }
    }

    private func receive(_ text: String) {
        guard phase == .listening, !isFinishing else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        listener.setMuted(true)
        lastUserLine = trimmed
        turns += 1
        append(.init(order: lines.count, isYou: true, text: trimmed))
        phase = .thinking
        liveLine = ""
        turnTask = Task { await respond() }
    }

    private func respond() async {
        let wrapping = turns >= maximumTurns || remaining <= 0
        do {
            let reply = wrapping
                ? try await tutor.closing(onPartial: { [weak self] partial in self?.liveLine = partial })
                : try await tutor.reply(to: lastUserLine, onPartial: { [weak self] partial in self?.liveLine = partial })
            guard !isFinishing else { return }
            append(.init(order: lines.count, isYou: false, text: reply))
            liveLine = reply
            phase = .speaking
            await speaker.say(reply, language: language)
            guard !isFinishing else { return }
            if wrapping {
                turnTask = nil
                await end()
            } else {
                phase = .listening
                liveLine = ""
                listener.setMuted(false)
            }
        } catch is CancellationError {
            return
        } catch {
            await fail(error)
        }
    }

    /// Hang up. Safe to call from the End button at any point.
    func end() async {
        guard phase != .ended else { return }
        isFinishing = true
        turnTask?.cancel()
        turnTask = nil
        clockTask?.cancel()
        clockTask = nil
        listener.onUtterance = nil
        speaker.stop()
        await listener.stop()

        let seconds = startedAt.map { Int(Date.now.timeIntervalSince($0)) } ?? 0
        draft = SessionDraft(room: room, language: language, level: level, seconds: seconds, lines: lines)
        phase = .ended
    }

    private func fail(_ error: Error) async {
        turnTask?.cancel()
        clockTask?.cancel()
        listener.onUtterance = nil
        speaker.stop()
        await listener.stop()
        phase = .failed(Self.message(for: error))
    }

    /// Keeps the real reason visible, in words a learner can act on.
    private static func message(for error: Error) -> String {
        if let failure = error as? Listener.Failure {
            return failure.errorDescription ?? "The microphone stopped."
        }
        if let failure = error as? TutorError {
            return failure.errorDescription ?? "The tutor stopped."
        }
        if error is CancellationError {
            return "Cancelled."
        }
        return "The tutor stopped: \(error.localizedDescription)"
    }

    private func append(_ line: LineRecord) {
        lines.append(line)
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, let startedAt = self.startedAt else { continue }
                self.elapsed = Date.now.timeIntervalSince(startedAt)
            }
        }
    }
}
