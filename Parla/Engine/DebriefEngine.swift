import Foundation
import FoundationModels

// Structured output of the debrief model. The shape is the contract between
// the model and the screen: three short arrays and one warm sentence.

@Generable
struct DebriefDraft {
    @Guide(description: "One or two warm, specific sentences about how the conversation went. Nothing that could be said to anyone.")
    var opening: String

    @Guide(description: "Two or three concrete things the learner actually did well, each quoting their own words.")
    var landed: [String]

    @Guide(description: "The corrections, most useful first. Empty when they made no notable mistake.")
    var notes: [DebriefNoteDraft]

    @Guide(description: "Two or three short phrases from this conversation worth keeping.")
    var phrases: [DebriefPhraseDraft]
}

@Generable
struct DebriefNoteDraft {
    @Guide(description: "The learner's exact words, quoted without comment and without quotation marks.")
    var youSaid: String

    @Guide(description: "Their sentence rewritten the way a native speaker would say it. Same meaning, same register, nothing added.")
    var trySaying: String

    @Guide(description: "One short English sentence explaining the change. Never scold, never use wrong, error, bad or mistake.")
    var why: String

    @Guide(description: "The kind of change", .anyOf(["grammar", "wordChoice", "naturalness"]))
    var kind: String
}

@Generable
struct DebriefPhraseDraft {
    @Guide(description: "A short phrase in the practice language, sayable in one breath.")
    var phrase: String

    @Guide(description: "What it means, in a few English words.")
    var gloss: String
}

enum DebriefEngine {
    /// How much correcting the learner asked for.
    enum Depth: String, CaseIterable, Sendable {
        case light, balanced, thorough

        var title: String {
            switch self {
            case .light: "Light"
            case .balanced: "Balanced"
            case .thorough: "Thorough"
            }
        }

        var maximumNotes: Int {
            switch self {
            case .light: 1
            case .balanced: 3
            case .thorough: 5
            }
        }
    }

    static func make(
        room: Room,
        language: PracticeLanguage,
        level: Level,
        depth: Depth,
        lines: [LineRecord]
    ) async throws -> DebriefDraft {
        guard SystemLanguageModel.default.isAvailable else { throw TutorError.modelUnavailable }

        let session = LanguageModelSession(instructions: instructions(language: language, level: level, depth: depth))
        let prompt = """
        Transcript of a spoken conversation in \(language.name).

        \(render(lines))

        Write the debrief now.
        """
        let response = try await session.respond(
            to: prompt,
            generating: DebriefDraft.self,
            options: GenerationOptions(temperature: 0.6, maximumResponseTokens: 900)
        )
        return response.content
    }

    static func render(_ lines: [LineRecord]) -> String {
        lines
            .sorted { $0.order < $1.order }
            .map { "\($0.isYou ? "Learner" : "Native speaker"): \($0.text)" }
            .joined(separator: "\n")
    }

    static func instructions(language: PracticeLanguage, level: Level, depth: Depth) -> String {
        """
        You are an exact and kind language teacher. You are writing the debrief that a learner reads \
        thirty seconds after finishing a spoken \(language.name) conversation. They are at level \(level.cefr).

        Rules:
        - Be specific. Quote their words. Generic encouragement is worthless and will be noticed.
        - Never write wrong, error, mistake, incorrect, bad or fail. Point at what a native speaker would say instead.
        - Give at most \(depth.maximumNotes) corrections: \(depthHint(depth))
        - Prefer a pattern they repeated over a one-off slip. If a sentence was already natural, do not invent a change.
        - Keep their meaning, register and personality. Never make them sound more formal or more polite than they were.
        - Each explanation is one short English sentence, plain words, no grammar lecture.
        - Phrases must be things they could reuse tomorrow, exactly as a native speaker would say them.
        - No em dashes. No emoji. No lists or semicolons inside a field.
        """
    }

    private static func depthHint(_ depth: Depth) -> String {
        switch depth {
        case .light: "only the single change that would help them most, and often none at all."
        case .balanced: "the three changes that unlock the most, ordered by usefulness."
        case .thorough: "up to five changes, ordered by usefulness."
        }
    }
}
