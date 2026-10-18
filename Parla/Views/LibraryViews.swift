import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Practice.startedAt, order: .reverse) private var practices: [Practice]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                if practices.isEmpty {
                    empty
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(practices.enumerated()), id: \.element.id) { index, practice in
                            if index > 0 { Hairline() }
                            NavigationLink(value: Route.practice(practice.id)) {
                                row(practice)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, MacInset.top)
            .padding(.bottom, Theme.Space.l)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Theme.paper(scheme).ignoresSafeArea())
        .navigationTitle("Debriefs")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private func row(_ practice: Practice) -> some View {
        HStack(alignment: .center, spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: 3) {
                Text(practice.room.title)
                    .font(.display(20))
                    .foregroundStyle(Theme.ink(scheme))
                Text("\(practice.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(max(1, practice.seconds / 60)) min")
                    .font(.label(11, weight: .medium))
                    .foregroundStyle(Theme.inkSoft(scheme))
            }
            Spacer(minLength: 0)
            if !practice.notes.isEmpty {
                Text("\(practice.notes.count)")
                    .font(.label(12, weight: .semibold))
                    .foregroundStyle(Theme.accent(scheme))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft(scheme).opacity(0.6))
        }
        .padding(.vertical, Theme.Space.m)
        .contentShape(Rectangle())
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("Nothing yet")
                .font(.display(26))
                .foregroundStyle(Theme.ink(scheme))
            Text("Finish a room and its debrief waits here.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.inkSoft(scheme))
        }
        .padding(.top, Theme.Space.xl)
    }
}

struct PhrasebookView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(Preferences.self) private var preferences
    @Query(sort: \Phrase.createdAt, order: .reverse) private var phrases: [Phrase]
    @State private var speaker = Speaker()

    private var shown: [Phrase] {
        phrases.filter { $0.languageCode == preferences.language.code }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                if shown.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text("Phrases you keep")
                            .font(.display(26))
                            .foregroundStyle(Theme.ink(scheme))
                        Text("Each debrief leaves two or three here, in \(preferences.language.name).")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.inkSoft(scheme))
                    }
                    .padding(.top, Theme.Space.xl)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element.persistentModelID) { index, phrase in
                            if index > 0 { Hairline() }
                            row(phrase)
                        }
                    }
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, MacInset.top)
            .padding(.bottom, Theme.Space.l)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Theme.paper(scheme).ignoresSafeArea())
        .navigationTitle("Phrases")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private func row(_ phrase: Phrase) -> some View {
        HStack(alignment: .center, spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: 3) {
                Text(phrase.text)
                    .font(.display(20))
                    .foregroundStyle(Theme.ink(scheme))
                    .fixedSize(horizontal: false, vertical: true)
                Text(phrase.gloss)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft(scheme))
            }
            Spacer(minLength: 0)
            SpeakButton {
                Task { await speaker.say(phrase.text, language: PracticeLanguage.named(phrase.languageCode)) }
            }
        }
        .padding(.vertical, Theme.Space.m)
    }
}
