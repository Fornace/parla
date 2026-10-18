import FoundationModels
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(Preferences.self) private var preferences
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Practice.startedAt, order: .reverse) private var practices: [Practice]

    @Environment(\.scenePhase) private var scenePhase

    private var topInset: CGFloat {
        #if os(macOS)
        34
        #else
        Theme.Space.m
        #endif
    }
    @State private var chosenRoom: Room?

    private var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    private var nextRoom: Room {
        Room.suggestion(completed: Set(practices.map(\.roomID)))
    }

    private var streak: Int { PracticeStats.streak(practices) }
    private var week: [Bool] { PracticeStats.lastSevenDays(practices) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                header
                hero
                if availability != .available {
                    ModelGate(availability: availability)
                }
                nextCard
                rooms
                if let last = practices.first {
                    lastDebrief(last)
                }
                footer
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, topInset)
            .padding(.bottom, Theme.Space.xxl)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper(scheme))
        .scrollIndicators(.hidden)
        .task { openPendingRoomIfAny() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { openPendingRoomIfAny() }
        }
        .sessionCover(item: $chosenRoom) { room in
            SessionFlow(
                room: room,
                language: preferences.language,
                level: preferences.level,
                depth: preferences.depth,
                voiceRate: preferences.voiceRate
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Parla")
                .font(.display(24, weight: .semibold))
                .foregroundStyle(Theme.ink(scheme))

            Spacer()

            languageMenu

            NavigationLink(value: Route.settings) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkSoft(scheme))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
    }

    private var languageMenu: some View {
        Menu {
            ForEach(PracticeLanguage.all) { language in
                Button {
                    preferences.language = language
                } label: {
                    if language == preferences.language {
                        Label(language.name, systemImage: "checkmark")
                    } else {
                        Text(language.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(preferences.language.nativeName)
                    .font(.label(14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Theme.ink(scheme))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .overlay(
                Capsule().stroke(Theme.line(scheme), lineWidth: 1)
            )
            .padding(.trailing, Theme.Space.s)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Say it out loud.")
                    .font(.display(46, weight: .regular))
                    .foregroundStyle(Theme.ink(scheme))
                    .lineSpacing(2)
                Spacer(minLength: 0)
                if streak > 0 {
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(streak == 1 ? "1 day" : "\(streak) days")
                            .font(.label(12, weight: .semibold))
                            .foregroundStyle(Theme.ink(scheme))
                        StreakDots(days: week)
                    }
                    .padding(.bottom, 6)
                }
            }
            Text("Talk for a few minutes. Then read what to change.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.inkSoft(scheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nextCard: some View {
        Card(padding: Theme.Space.l) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack(spacing: Theme.Space.xs) {
                    Text("NEXT ROOM")
                    Text("·")
                    Text("\(nextRoom.level.badge) · \(nextRoom.minutes) min")
                }
                .font(.label(11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.accentInk(scheme))

                VStack(alignment: .leading, spacing: 6) {
                    Text(nextRoom.title)
                        .font(.display(31))
                        .foregroundStyle(Theme.ink(scheme))
                    Text(nextRoom.subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.inkSoft(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                PrimaryButton(title: "Start talking", systemImage: "arrow.right") {
                    chosenRoom = nextRoom
                }
                .disabled(availability != .available)
                .opacity(availability == .available ? 1 : 0.45)
            }
        }
    }

    private var rooms: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Eyebrow(text: "Other rooms")
            VStack(spacing: 0) {
                let others = Room.all.filter { $0.id != nextRoom.id }
                ForEach(Array(others.enumerated()), id: \.element.id) { position, room in
                    if position > 0 { Hairline() }
                    RoomRow(
                        room: room,
                        number: (Room.all.firstIndex(of: room) ?? 0) + 1,
                        done: practices.contains { $0.roomID == room.id }
                    ) {
                        chosenRoom = room
                    }
                    .disabled(availability != .available)
                }
            }
            .padding(.horizontal, Theme.Space.m)
            .background(Theme.surface(scheme))
            .clipShape(.rect(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.line(scheme), lineWidth: 1)
            )
        }
    }

    private func lastDebrief(_ practice: Practice) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Eyebrow(text: "Last time")
            NavigationLink(value: Route.practice(practice.id)) {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(practice.room.title)
                            .font(.display(21))
                            .foregroundStyle(Theme.ink(scheme))
                        if let note = practice.sortedNotes.first {
                            Text(note.trySaying)
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.ink(scheme))
                                .lineLimit(2)
                            Text(NoteKind.label(for: note.kind))
                                .font(.label(11, weight: .medium))
                                .foregroundStyle(Theme.inkSoft(scheme))
                        } else {
                            Text("Read it again")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.inkSoft(scheme))
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack(spacing: Theme.Space.s) {
                NavigationLink(value: Route.history) {
                    Text("Debriefs")
                        .font(.label(15, weight: .medium))
                        .foregroundStyle(Theme.ink(scheme))
                        .padding(.horizontal, Theme.Space.m)
                        .padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Theme.line(scheme), lineWidth: 1))
                }
                .buttonStyle(.plain)

                NavigationLink(value: Route.phrasebook) {
                    Text("Phrases")
                        .font(.label(15, weight: .medium))
                        .foregroundStyle(Theme.ink(scheme))
                        .padding(.horizontal, Theme.Space.m)
                        .padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Theme.line(scheme), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            Hairline()
            Text("Runs on this device. Your voice never leaves it.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft(scheme))
        }
    }

    /// Opened from the widget or Siri: start the room that was asked for.
    private func openPendingRoomIfAny() {
        guard availability == .available, chosenRoom == nil else { return }
        guard let id = SharedStore.takePendingScene() else { return }
        chosenRoom = Room.byID(id)
    }
}

/// One room in the index: number, name, and what it costs you in minutes.
private struct RoomRow: View {
    let room: Room
    let number: Int
    let done: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
                Text(number < 10 ? "0\(number)" : "\(number)")
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.inkSoft(scheme))
                    .monospacedDigit()
                    .frame(width: 24, alignment: .leading)
                Text(room.title)
                    .font(.display(19))
                    .foregroundStyle(Theme.ink(scheme))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Theme.Space.s)
                Text("\(room.level.badge) · \(room.minutes) min")
                    .font(.label(12, weight: .medium))
                    .foregroundStyle(Theme.inkSoft(scheme))
                    .lineLimit(1)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.moss(scheme))
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

enum PracticeStats {
    /// Consecutive days with at least one finished session, ending today or
    /// yesterday (yesterday keeps the streak alive until the day is over).
    static func streak(_ practices: [Practice]) -> Int {
        let calendar = Calendar.current
        let days = Set(practices.map { calendar.startOfDay(for: $0.startedAt) })
        guard !days.isEmpty else { return 0 }
        let today = calendar.startOfDay(for: .now)
        var cursor = days.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        if !days.contains(cursor) { return 0 }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    static func lastSevenDays(_ practices: [Practice]) -> [Bool] {
        let calendar = Calendar.current
        let days = Set(practices.map { calendar.startOfDay(for: $0.startedAt) })
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return false }
            return days.contains(day)
        }
    }
}
