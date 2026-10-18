import AppIntents
import Foundation

/// The rooms, exposed to Siri, Shortcuts and the widget.
enum RoomChoice: String, AppEnum, CaseIterable {
    case cafe, flat, studio, train, dinner, interview, neighbour, blank

    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Room") }

    static var caseDisplayRepresentations: [RoomChoice: DisplayRepresentation] {
        [
            .cafe: DisplayRepresentation(title: "The late café"),
            .flat: DisplayRepresentation(title: "A flat viewing"),
            .studio: DisplayRepresentation(title: "First day at the studio"),
            .train: DisplayRepresentation(title: "The delayed train"),
            .dinner: DisplayRepresentation(title: "Dinner with the in-laws"),
            .interview: DisplayRepresentation(title: "The interview"),
            .neighbour: DisplayRepresentation(title: "The noisy neighbour"),
            .blank: DisplayRepresentation(title: "No script"),
        ]
    }

    var room: Room { Room.byID(rawValue) }
}

struct StartRoomIntent: AppIntent {
    static var title: LocalizedStringResource { "Start a room" }
    static var description: IntentDescription { IntentDescription("Opens Parla and starts talking in a room.") }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Room")
    var room: RoomChoice

    init() {
        room = .cafe
    }

    init(room: RoomChoice) {
        self.room = room
    }

    func perform() async throws -> some IntentResult {
        SharedStore.setPendingScene(room.rawValue)
        return .result()
    }
}

/// The widget and Siri entry point: the room you were last in, or the next one.
struct PracticeNowIntent: AppIntent {
    static var title: LocalizedStringResource { "Practise now" }
    static var description: IntentDescription { IntentDescription("Opens Parla in the room you should walk into next.") }
    static var openAppWhenRun: Bool { true }

    init() {}

    func perform() async throws -> some IntentResult {
        let roomID = SharedStore.read()?.lastRoomID ?? Room.all[0].id
        SharedStore.setPendingScene(roomID)
        return .result()
    }
}

struct ParlaShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .orange }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PracticeNowIntent(),
            phrases: [
                "Practise with \(.applicationName)",
                "Talk with \(.applicationName)",
            ],
            shortTitle: "Practise",
            systemImageName: "waveform"
        )
        AppShortcut(
            intent: StartRoomIntent(),
            phrases: [
                "Open a room in \(.applicationName)",
                "Start \(\.$room) in \(.applicationName)",
            ],
            shortTitle: "Start a room",
            systemImageName: "door.left.hand.open"
        )
    }
}
