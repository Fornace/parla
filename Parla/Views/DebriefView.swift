import SwiftData
import SwiftUI

/// The debrief layout, shared by the live session and the saved ones.
struct DebriefContent: View {
    let meta: String
    let title: String
    let opening: String
    let landed: [String]
    let notes: [NoteRecord]
    let phrases: [PhraseRecord]
    let language: PracticeLanguage

    @Environment(\.colorScheme) private var scheme
    @State private var speaker = Speaker()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text(meta.uppercased())
                    .font(.label(11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.accentInk(scheme))
                Text(title)
                    .font(.display(32))
                    .foregroundStyle(Theme.ink(scheme))
                if !opening.isEmpty {
                    Text(opening)
                        .font(.display(19))
                        .foregroundStyle(Theme.ink(scheme))
                        .lineSpacing(4)
                        .padding(.top, 2)
                }
            }

            if !landed.isEmpty {
                section("What landed") {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        ForEach(Array(landed.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .firstTextBaseline, spacing: 9) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.moss(scheme))
                                Text(item)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.ink(scheme))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            if !notes.isEmpty {
                section(notes.count == 1 ? "One small change" : "\(Self.word(notes.count)) small changes") {
                    VStack(spacing: Theme.Space.s) {
                        ForEach(notes) { note in
                            NoteCard(note: note)
                        }
                    }
                }
            }

            if !phrases.isEmpty {
                section("To carry") {
                    VStack(spacing: 0) {
                        ForEach(Array(phrases.enumerated()), id: \.element.id) { index, phrase in
                            if index > 0 { Hairline() }
                            HStack(alignment: .center, spacing: Theme.Space.s) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(phrase.text)
                                        .font(.display(19))
                                        .foregroundStyle(Theme.ink(scheme))
                                        .fixedSize(horizontal: false, vertical: true)
                                    if !phrase.gloss.isEmpty {
                                        Text(phrase.gloss)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Theme.inkSoft(scheme))
                                    }
                                }
                                Spacer(minLength: 0)
                                SpeakButton {
                                    Task { await speaker.say(phrase.text, language: language) }
                                }
                            }
                            .padding(.vertical, Theme.Space.s)
                        }
                    }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Eyebrow(text: title)
            content()
        }
    }

    private static func word(_ count: Int) -> String {
        switch count {
        case 1: "One"
        case 2: "Two"
        case 3: "Three"
        case 4: "Four"
        default: "\(count)"
        }
    }
}

private struct NoteCard: View {
    let note: NoteRecord
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            Rectangle()
                .fill(Theme.accent(scheme).opacity(0.55))
                .frame(width: 2)
                .clipShape(.capsule)

            VStack(alignment: .leading, spacing: 7) {
                Text(note.youSaid)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft(scheme))
                    .strikethrough(false)
                    .fixedSize(horizontal: false, vertical: true)

                Text(note.trySaying)
                    .font(.display(20, weight: .medium))
                    .foregroundStyle(Theme.ink(scheme))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(NoteKind.label(for: note.kind).uppercased())
                        .font(.label(9, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Theme.accentInk(scheme))
                    Text(note.why)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSoft(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 2)
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface(scheme))
        .clipShape(.rect(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.line(scheme), lineWidth: 1)
        )
    }
}

/// The debrief right after a conversation.
struct DebriefView: View {
    let room: Room
    let language: PracticeLanguage
    let seconds: Int
    let draft: DebriefDraft
    let saveProblem: String?
    let onDone: () -> Void

    @Environment(\.colorScheme) private var scheme

    private var notes: [NoteRecord] {
        draft.notes.enumerated().map { index, note in
            NoteRecord(order: index, youSaid: note.youSaid, trySaying: note.trySaying, why: note.why, kind: note.kind)
        }
    }

    private var phrases: [PhraseRecord] {
        draft.phrases.map {
            PhraseRecord(text: $0.phrase, gloss: $0.gloss, languageCode: language.code, roomID: room.id)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                DebriefContent(
                    meta: "\(room.title) · \(max(1, seconds / 60)) min · \(language.name)",
                    title: "You spoke.",
                    opening: draft.opening,
                    landed: draft.landed,
                    notes: notes,
                    phrases: phrases,
                    language: language
                )

                if let saveProblem {
                    Text(saveProblem)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accent(scheme))
                }

                PrimaryButton(title: "Done", action: onDone)
                    .padding(.top, Theme.Space.s)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, Theme.Space.xl)
            .padding(.bottom, Theme.Space.xxl)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper(scheme).ignoresSafeArea())
        .scrollIndicators(.hidden)
    }
}

/// A debrief reopened from the history.
struct SavedDebriefView: View {
    let practiceID: UUID
    @Environment(\.colorScheme) private var scheme
    @Query private var matches: [Practice]

    init(practiceID: UUID) {
        self.practiceID = practiceID
        _matches = Query(filter: #Predicate<Practice> { $0.id == practiceID })
    }

    var body: some View {
        Group {
            if let practice = matches.first {
                ScrollView {
                    DebriefContent(
                        meta: "\(practice.room.title) · \(max(1, practice.seconds / 60)) min · \(practice.room.level.cefr)",
                        title: practice.startedAt.formatted(date: .abbreviated, time: .shortened),
                        opening: practice.opening,
                        landed: practice.landed,
                        notes: practice.sortedNotes.map {
                            NoteRecord(order: $0.order, youSaid: $0.youSaid, trySaying: $0.trySaying, why: $0.why, kind: $0.kind)
                        },
                        phrases: [],
                        language: practice.language
                    )
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(Theme.Space.l)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            } else {
                Text("That session is gone.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.inkSoft(scheme))
            }
        }
        .background(Theme.paper(scheme).ignoresSafeArea())
        .navigationTitle("Debrief")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
