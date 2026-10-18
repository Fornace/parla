import Foundation

/// One finished conversation, kept on device.
struct PracticeRecord: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var startedAt: Date
    var languageCode: String
    var roomID: String
    var seconds: Int
    var opening: String
    var landed: [String]
    var notes: [NoteRecord]
    var phrases: [PhraseRecord]
    var lines: [LineRecord]
}

struct LineRecord: Codable, Hashable, Sendable {
    var order: Int
    var isYou: Bool
    var text: String
}

struct NoteRecord: Codable, Hashable, Sendable, Identifiable {
    var id = UUID()
    var order: Int
    var youSaid: String
    var trySaying: String
    var why: String
    var kind: String

    var kindLabel: String {
        switch kind {
        case "grammar": "Grammar"
        case "wordChoice": "Word choice"
        case "naturalness": "Sounds foreign"
        default: "Wording"
        }
    }
}

struct PhraseRecord: Codable, Hashable, Sendable, Identifiable {
    var id = UUID()
    var text: String
    var gloss: String
    var languageCode: String
    var roomID: String
    var createdAt: Date = .now
}

/// What the home screen and the widget need to know without opening the app.
struct PracticeSnapshot: Codable, Hashable, Sendable {
    var streak: Int
    var practisedToday: Bool
    var lastRoomID: String
    var lastRoomTitle: String
    var lastNote: String
    var languageCode: String
    var phrase: String
    var phraseGloss: String
    var updatedAt: Date

    static let empty = PracticeSnapshot(
        streak: 0,
        practisedToday: false,
        lastRoomID: Room.all[0].id,
        lastRoomTitle: Room.all[0].title,
        lastNote: "",
        languageCode: "es",
        phrase: "",
        phraseGloss: "",
        updatedAt: .distantPast
    )
}

/// App Group handoff between the app, the widget and App Intents.
enum SharedStore {
    static let appGroup = "group.app.fornace.parla"
    private static let snapshotKey = "practice.snapshot.v1"
    private static let pendingKey = "practice.pendingScene"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func write(_ snapshot: PracticeSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: snapshotKey)
    }

    static func read() -> PracticeSnapshot? {
        guard let data = defaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(PracticeSnapshot.self, from: data)
    }

    static func setPendingScene(_ id: String) {
        defaults?.set(id, forKey: pendingKey)
    }

    static func takePendingScene() -> String? {
        guard let id = defaults?.string(forKey: pendingKey) else { return nil }
        defaults?.removeObject(forKey: pendingKey)
        return id
    }
}
