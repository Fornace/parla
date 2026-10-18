import SwiftData
import SwiftUI

/// One visit to a room: talk, then read what to change, then leave.
struct SessionFlow: View {
    enum Stage: Equatable { case talking, composing, reading, failed(String) }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    let room: Room
    let language: PracticeLanguage
    let level: Level
    let depth: DebriefEngine.Depth
    let voiceRate: Double

    @State private var conversation: Conversation
    @State private var stage: Stage = .talking
    @State private var debrief: DebriefDraft?
    @State private var saveProblem: String?

    init(room: Room, language: PracticeLanguage, level: Level, depth: DebriefEngine.Depth, voiceRate: Double) {
        self.room = room
        self.language = language
        self.level = level
        self.depth = depth
        self.voiceRate = voiceRate
        _conversation = State(initialValue: Conversation(room: room, language: language, level: level))
        _conversation.wrappedValue.speaker.rate = Float(voiceRate)
    }

    var body: some View {
        Group {
            switch stage {
            case .talking:
                TalkingView(conversation: conversation, room: room, language: language, onClose: { dismiss() })
            case .composing:
                ComposingView(room: room)
            case .reading:
                if let debrief {
                    DebriefView(
                        room: room,
                        language: language,
                        seconds: conversation.draft?.seconds ?? 0,
                        draft: debrief,
                        saveProblem: saveProblem,
                        onDone: { dismiss() }
                    )
                }
            case .failed(let message):
                DebriefFailure(message: message, onRetry: { Task { await compose() } }, onClose: { dismiss() })
            }
        }
        .onChange(of: conversation.phase) { _, phase in
            guard phase == .ended, stage == .talking else { return }
            stage = .composing
            Task { await compose() }
        }
    }

    private func compose() async {
        guard let draft = conversation.draft else { return }
        stage = .composing
        do {
            Log.debrief.info("composing debrief from \(draft.lines.count, privacy: .public) lines")
            let result = try await DebriefEngine.make(
                room: room,
                language: language,
                level: level,
                depth: depth,
                lines: draft.lines
            )
            debrief = result
            save(draft: draft, result: result)
            stage = .reading
        } catch {
            Log.debrief.error("debrief failed: \(error.localizedDescription, privacy: .public)")
            stage = .failed(error.localizedDescription)
        }
    }

    private func save(draft: SessionDraft, result: DebriefDraft) {
        let record = PracticeRecord(
            id: UUID(),
            startedAt: .now,
            languageCode: language.code,
            roomID: room.id,
            seconds: draft.seconds,
            opening: result.opening,
            landed: result.landed,
            notes: result.notes.enumerated().map { index, note in
                NoteRecord(
                    order: index,
                    youSaid: note.youSaid,
                    trySaying: note.trySaying,
                    why: note.why,
                    kind: note.kind
                )
            },
            phrases: result.phrases.map { phrase in
                PhraseRecord(
                    text: phrase.phrase,
                    gloss: phrase.gloss,
                    languageCode: language.code,
                    roomID: room.id
                )
            },
            lines: draft.lines
        )

        let practice = Practice(record: record)
        context.insert(practice)
        for phrase in record.phrases {
            context.insert(Phrase(record: phrase))
        }
        do {
            try context.save()
            Log.store.info("saved practice \(record.roomID, privacy: .public)")
        } catch {
            saveProblem = "This session could not be saved: \(error.localizedDescription)"
        }

        // The widget reads this: the real streak, not a guess.
        let all = (try? context.fetch(FetchDescriptor<Practice>())) ?? [practice]
        SharedStore.write(
            PracticeSnapshot(
                streak: PracticeStats.streak(all),
                practisedToday: true,
                lastRoomID: room.id,
                lastRoomTitle: room.title,
                lastNote: record.notes.first?.trySaying ?? record.opening,
                languageCode: language.code,
                phrase: record.phrases.first?.text ?? "",
                phraseGloss: record.phrases.first?.gloss ?? "",
                updatedAt: .now
            )
        )
    }
}

private struct ComposingView: View {
    let room: Room
    @State private var visible = false

    var body: some View {
        VStack(spacing: Theme.Space.m) {
            Text("Reading the conversation")
                .font(.display(24))
                .foregroundStyle(Theme.stageInk)
            Text(room.title)
                .font(.label(12, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Theme.stageSoft)
                .textCase(.uppercase)
            EqualizerBars(active: visible, tint: Theme.stageAccent)
                .frame(width: 40, height: 18)
                .padding(.top, Theme.Space.s)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.stage.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { visible = true }
    }
}

private struct DebriefFailure: View {
    let message: String
    let onRetry: () -> Void
    let onClose: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Spacer()
            Text("The debrief did not come through.")
                .font(.display(26))
                .foregroundStyle(Theme.ink(scheme))
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft(scheme))
            PrimaryButton(title: "Try again", action: onRetry)
                .padding(.top, Theme.Space.s)
            GhostButton(title: "Close", action: onClose)
            Spacer()
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.paper(scheme).ignoresSafeArea())
    }
}
