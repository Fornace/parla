import Foundation
import SwiftData

/// A finished practice session. The debrief is stored alongside the lines it
/// was drawn from, so a saved debrief can always be read back in context.
@Model
final class Practice {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var languageCode: String = "es"
    var roomID: String = "cafe"
    var seconds: Int = 0
    var opening: String = ""
    var landed: [String] = []

    @Relationship(deleteRule: .cascade, inverse: \Line.practice)
    var lines: [Line] = []

    @Relationship(deleteRule: .cascade, inverse: \Note.practice)
    var notes: [Note] = []

    init(record: PracticeRecord) {
        id = record.id
        startedAt = record.startedAt
        languageCode = record.languageCode
        roomID = record.roomID
        seconds = record.seconds
        opening = record.opening
        landed = record.landed
        lines = record.lines.map(Line.init(record:))
        notes = record.notes.map(Note.init(record:))
    }

    var room: Room { Room.byID(roomID) }
    var language: PracticeLanguage { PracticeLanguage.named(languageCode) }
    var sortedLines: [Line] { lines.sorted { $0.order < $1.order } }
    var sortedNotes: [Note] { notes.sorted { $0.order < $1.order } }
}

@Model
final class Line {
    var order: Int = 0
    var isYou: Bool = true
    var text: String = ""
    var practice: Practice?

    init(record: LineRecord) {
        order = record.order
        isYou = record.isYou
        text = record.text
    }
}

@Model
final class Note {
    var order: Int = 0
    var youSaid: String = ""
    var trySaying: String = ""
    var why: String = ""
    var kind: String = "grammar"
    var practice: Practice?

    init(record: NoteRecord) {
        order = record.order
        youSaid = record.youSaid
        trySaying = record.trySaying
        why = record.why
        kind = record.kind
    }

    var kindLabel: String {
        NoteRecord(order: order, youSaid: "", trySaying: "", why: "", kind: kind).kindLabel
    }
}

/// A phrase worth carrying out of a conversation.
@Model
final class Phrase {
    var text: String = ""
    var gloss: String = ""
    var languageCode: String = "es"
    var roomID: String = "cafe"
    var createdAt: Date = Date.now

    init(record: PhraseRecord) {
        text = record.text
        gloss = record.gloss
        languageCode = record.languageCode
        roomID = record.roomID
        createdAt = record.createdAt
    }
}

enum Store {
    @MainActor
    static func container() -> ModelContainer {
        let schema = Schema([Practice.self, Line.self, Note.self, Phrase.self])
        let configuration = ModelConfiguration("Parla", schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // A broken store is a real failure: report it rather than silently
            // running an in-memory app that loses the learner's history.
            fatalError("Parla could not open its local store: \(error)")
        }
    }
}
