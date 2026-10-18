import Foundation
import Observation

/// The learner's choices, small enough to live in UserDefaults.
@MainActor
@Observable
final class Preferences {
    private enum Key {
        static let language = "practice.language"
        static let level = "practice.level"
        static let depth = "practice.depth"
        static let voiceRate = "practice.voiceRate"
    }

    private let defaults: UserDefaults

    var language: PracticeLanguage {
        didSet { defaults.set(language.code, forKey: Key.language) }
    }

    var level: Level {
        didSet { defaults.set(level.rawValue, forKey: Key.level) }
    }

    var depth: DebriefEngine.Depth {
        didSet { defaults.set(depth.rawValue, forKey: Key.depth) }
    }

    var voiceRate: Double {
        didSet { defaults.set(voiceRate, forKey: Key.voiceRate) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Practise the language you are unlikely to already speak: English for
        // everyone else, Spanish for English speakers.
        let system = Locale.current.language.languageCode?.identifier ?? "en"
        let suggested = system == "en" ? "es" : "en"
        let code = defaults.string(forKey: Key.language) ?? suggested
        self.language = PracticeLanguage.named(code)
        self.level = Level(rawValue: defaults.string(forKey: Key.level) ?? "") ?? .finding
        self.depth = DebriefEngine.Depth(rawValue: defaults.string(forKey: Key.depth) ?? "") ?? .balanced
        let rate = defaults.double(forKey: Key.voiceRate)
        self.voiceRate = rate == 0 ? 0.46 : rate
    }
}
