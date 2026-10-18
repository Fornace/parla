import Foundation
import FoundationModels

enum TutorError: LocalizedError {
    case modelUnavailable
    case emptyReply

    var errorDescription: String? {
        switch self {
        case .modelUnavailable: "The on-device model is not available right now."
        case .emptyReply: "The tutor had nothing to say. Try saying that again."
        }
    }
}

/// The half of the conversation that speaks the practice language.
@MainActor
final class Tutor {
    let room: Room
    let language: PracticeLanguage
    let level: Level

    private var session: LanguageModelSession?

    init(room: Room, language: PracticeLanguage, level: Level) {
        self.room = room
        self.language = language
        self.level = level
    }

    static var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    private var options: GenerationOptions {
        GenerationOptions(temperature: 0.85, maximumResponseTokens: 140)
    }

    private func makeSession() throws -> LanguageModelSession {
        if let session { return session }
        guard SystemLanguageModel.default.isAvailable else { throw TutorError.modelUnavailable }
        let session = LanguageModelSession(instructions: Self.instructions(room: room, language: language, level: level))
        self.session = session
        return session
    }

    func warmUp() {
        session = try? makeSession()
        session?.prewarm()
    }

    /// The tutor's first line, in character.
    func opening(onPartial: @MainActor (String) -> Void = { _ in }) async throws -> String {
        try await turn(
            prompt: "The room begins. Greet them in character with one short line, then leave room for them to answer.",
            onPartial: onPartial
        )
    }

    func reply(to utterance: String, onPartial: @MainActor (String) -> Void = { _ in }) async throws -> String {
        try await turn(prompt: utterance, onPartial: onPartial)
    }

    /// Closing line when the room has run its course.
    func closing(onPartial: @MainActor (String) -> Void = { _ in }) async throws -> String {
        try await turn(
            prompt: "Time is up. Bring the room to a warm close in one or two sentences and say goodbye in character. Do not ask a question.",
            onPartial: onPartial
        )
    }

    private func turn(prompt: String, onPartial: @MainActor (String) -> Void) async throws -> String {
        let session = try makeSession()
        Log.tutor.debug("turn start")
        var latest = ""
        let stream = session.streamResponse(to: prompt, options: options)
        for try await snapshot in stream {
            latest = snapshot.content
            onPartial(latest)
        }
        let trimmed = latest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TutorError.emptyReply }
        Log.tutor.debug("turn finished with \(trimmed.count, privacy: .public) characters")
        return trimmed
    }

    static func instructions(room: Room, language: PracticeLanguage, level: Level) -> String {
        """
        You are Parla, a conversation partner for someone practising \(language.name) (\(language.nativeName)). \
        You always speak \(language.name), and you stay in character.

        The room: \(room.setup)

        They are practising \(language.name) at level \(level.cefr). \(level.instruction)

        How you talk:
        - One or two short sentences per turn. React to what they actually said, then leave the floor to them. At most one question per turn.
        - Never correct their language while you are talking. Never repeat their sentence back corrected. Never mention grammar, mistakes or how they are doing.
        - Never say you are an AI, a model, a tutor or a simulation. You are the person in the room.
        - If they are stuck or fall back into English, answer briefly in \(language.name) with something easy, then give them one simple question to answer.
        - If you did not catch something, ask them naturally to say it again.
        - Plain speech only: no lists, no emoji, no stage directions, no em dashes, no quotation marks around your own lines.
        - Keep the conversation heading towards this: \(room.goal)
        """
    }
}
