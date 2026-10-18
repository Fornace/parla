import Foundation

/// A language you can practise. Kept to the languages the on-device model
/// and the on-device transcriber both handle well.
struct PracticeLanguage: Identifiable, Hashable, Codable, Sendable {
    let code: String        // BCP-47 base: "es"
    let name: String        // English name: "Spanish"
    let nativeName: String  // "Español"

    var id: String { code }

    /// Locale handed to the transcriber and the voice.
    var locale: Locale { Locale(identifier: code) }

    static let all: [PracticeLanguage] = [
        .init(code: "es", name: "Spanish", nativeName: "Español"),
        .init(code: "fr", name: "French", nativeName: "Français"),
        .init(code: "it", name: "Italian", nativeName: "Italiano"),
        .init(code: "de", name: "German", nativeName: "Deutsch"),
        .init(code: "pt", name: "Portuguese", nativeName: "Português"),
        .init(code: "nl", name: "Dutch", nativeName: "Nederlands"),
        .init(code: "sv", name: "Swedish", nativeName: "Svenska"),
        .init(code: "da", name: "Danish", nativeName: "Dansk"),
        .init(code: "nb", name: "Norwegian", nativeName: "Norsk"),
        .init(code: "tr", name: "Turkish", nativeName: "Türkçe"),
        .init(code: "ja", name: "Japanese", nativeName: "日本語"),
        .init(code: "ko", name: "Korean", nativeName: "한국어"),
        .init(code: "zh", name: "Chinese", nativeName: "中文"),
        .init(code: "vi", name: "Vietnamese", nativeName: "Tiếng Việt"),
        .init(code: "en", name: "English", nativeName: "English"),
    ]

    static func named(_ code: String) -> PracticeLanguage {
        all.first { $0.code == code } ?? all[0]
    }
}

/// How much room the tutor leaves you.
enum Level: String, Codable, CaseIterable, Sendable {
    case starting, finding, steady, sure

    var title: String {
        switch self {
        case .starting: "Starting out"
        case .finding: "Finding words"
        case .steady: "Steady"
        case .sure: "Sure-footed"
        }
    }

    /// Plain word for the badge on a room card.
    var badge: String {
        switch self {
        case .starting: "Easy"
        case .finding: "Everyday"
        case .steady: "Confident"
        case .sure: "Fluent"
        }
    }

    var cefr: String {
        switch self {
        case .starting: "A2"
        case .finding: "B1"
        case .steady: "B2"
        case .sure: "C1"
        }
    }

    /// Written straight into the tutor prompt.
    var instruction: String {
        switch self {
        case .starting:
            "They are around A2. Use short sentences, present and near future only, and stay in the 300 most common words. Speak slowly."
        case .finding:
            "They are around B1. Everyday vocabulary, simple connectors, mostly present and past. Keep sentences short."
        case .steady:
            "They are around B2. Natural everyday speech, some idiom, subordinate clauses welcome. Normal pace."
        case .sure:
            "They are around C1. Speak as you would to a native friend: fast, idiomatic, with wit and interruption."
        }
    }
}

/// A social situation you can walk into.
struct Room: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    /// Who the tutor becomes and where you both are.
    let setup: String
    /// What the learner is trying to get out of the conversation.
    let goal: String
    let minutes: Int
    let level: Level

    static let all: [Room] = [
        Room(
            id: "cafe",
            title: "The late café",
            subtitle: "Order, ask for a seat, talk about your day",
            setup: "You are the owner of a small café, ten minutes before closing. The learner has just walked in. You are warm, a little tired, and happy to talk while you wipe the counter.",
            goal: "Order something, ask whether the kitchen is still open, and answer one question about their day.",
            minutes: 3,
            level: .starting
        ),
        Room(
            id: "flat",
            title: "A flat viewing",
            subtitle: "Ask the questions that actually matter",
            setup: "You are showing the learner a two-room flat you are renting out. You are friendly but in a hurry for the next viewing.",
            goal: "Ask about the rent, the heating, the neighbours and the length of the contract.",
            minutes: 4,
            level: .finding
        ),
        Room(
            id: "studio",
            title: "First day at the studio",
            subtitle: "Meet four strangers, remember three names",
            setup: "You are a designer at a small studio where the learner has just started. You meet them by the coffee machine on their first morning and introduce yourself.",
            goal: "Say what they do, where they come from, and ask a colleague a question back.",
            minutes: 4,
            level: .finding
        ),
        Room(
            id: "train",
            title: "The delayed train",
            subtitle: "Ask for options, complain without burning bridges",
            setup: "You work at the ticket desk of a station. The learner's train has been cancelled and the next one is in three hours. You are patient but the queue behind them is long.",
            goal: "Find out why the train is cancelled, ask for an alternative, and get something in writing for work.",
            minutes: 4,
            level: .finding
        ),
        Room(
            id: "dinner",
            title: "Dinner with the in-laws",
            subtitle: "Hold your own when everyone talks at once",
            setup: "You are the learner's partner's mother, hosting a loud Sunday lunch. Two other relatives keep cutting in; you are curious about the learner and not shy about asking.",
            goal: "Talk about family, work and plans, and disagree politely at least once.",
            minutes: 5,
            level: .steady
        ),
        Room(
            id: "interview",
            title: "The interview",
            subtitle: "Twenty minutes of tell me about a time",
            setup: "You are a hiring manager for a role the learner applied to. You have their CV open and you are thorough but fair.",
            goal: "Describe two past projects, explain a trade-off, and ask one question about the team.",
            minutes: 5,
            level: .steady
        ),
        Room(
            id: "neighbour",
            title: "The noisy neighbour",
            subtitle: "Say something difficult, keep the peace",
            setup: "You are the learner's upstairs neighbour. You got home late and made some noise. You are not unfriendly, but you do not think the noise is a big deal.",
            goal: "Explain the problem without apologising for having it, and agree on something concrete.",
            minutes: 4,
            level: .steady
        ),
        Room(
            id: "blank",
            title: "No script",
            subtitle: "An open conversation, wherever it goes",
            setup: "You are a new acquaintance at a party. There is no agenda. You are genuinely curious and lightly funny.",
            goal: "Keep a real conversation going and change the subject gracefully at least twice.",
            minutes: 5,
            level: .sure
        ),
    ]

    static func byID(_ id: String) -> Room {
        all.first { $0.id == id } ?? all[0]
    }

    /// Suggested next room: the first one the learner has not done.
    static func suggestion(completed: Set<String>) -> Room {
        all.first { !completed.contains($0.id) } ?? all[all.count - 1]
    }
}
