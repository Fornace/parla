import SwiftUI
import WidgetKit

struct PracticeEntry: TimelineEntry {
    let date: Date
    let snapshot: PracticeSnapshot
}

struct PracticeProvider: TimelineProvider {
    func placeholder(in context: Context) -> PracticeEntry {
        PracticeEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (PracticeEntry) -> Void) {
        completion(PracticeEntry(date: .now, snapshot: SharedStore.read() ?? .empty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PracticeEntry>) -> Void) {
        let entry = PracticeEntry(date: .now, snapshot: SharedStore.read() ?? .empty)
        let next = Calendar.current.date(byAdding: .hour, value: 3, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ParlaStreak", provider: PracticeProvider()) { entry in
            StreakView(entry: entry)
                .containerBackground(Theme.paper(.light), for: .widget)
        }
        .configurationDisplayName("Streak")
        .description("How many days in a row you have spoken.")
        .supportedFamilies([.systemSmall])
    }
}

struct PhraseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ParlaPhrase", provider: PracticeProvider()) { entry in
            PhraseView(entry: entry)
                .containerBackground(Theme.paper(.light), for: .widget)
        }
        .configurationDisplayName("A phrase to carry")
        .description("The last phrase worth keeping, and a way back in.")
        .supportedFamilies([.systemMedium])
    }
}

private struct StreakView: View {
    let entry: PracticeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.snapshot.streak == 1 ? "1 day" : "\(entry.snapshot.streak) days")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ink(.light))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(entry.snapshot.streak > 0 ? "of talking" : "Not yet")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft(.light))

            Spacer(minLength: 6)

            Button(intent: PracticeNowIntent()) {
                HStack(spacing: 5) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Talk")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.paper(.light))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.accent(.light))
                .clipShape(.capsule)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct PhraseView: View {
    let entry: PracticeEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.snapshot.phrase.isEmpty ? "A phrase worth keeping" : entry.snapshot.phrase)
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.ink(.light))
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                if !entry.snapshot.phraseGloss.isEmpty {
                    Text(entry.snapshot.phraseGloss)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSoft(.light))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Text(entry.snapshot.lastRoomTitle.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(Theme.accentInk(.light))
            }
            Spacer(minLength: 0)
            Button(intent: PracticeNowIntent()) {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.paper(.light))
                    .frame(width: 38, height: 38)
                    .background(Theme.accent(.light))
                    .clipShape(.circle)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
