import AVFoundation
import Foundation

/// Speaks the tutor's lines with the best voice installed for the language.
@MainActor
final class Speaker {
    private let synthesizer = AVSpeechSynthesizer()
    private var delegate: SpeechDelegate?

    /// 0.36 slow, 0.46 normal, 0.52 brisk.
    var rate: Float = 0.46

    private(set) var isSpeaking = false

    init() {
        let delegate = SpeechDelegate()
        delegate.onFinish = { [weak self] in
            self?.isSpeaking = false
            self?.finishContinuation?.resume()
            self?.finishContinuation = nil
        }
        synthesizer.delegate = delegate
        self.delegate = delegate
    }

    private var finishContinuation: CheckedContinuation<Void, Never>?

    func say(_ text: String, language: PracticeLanguage) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        stop()

        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = Self.voice(for: language)
        utterance.rate = rate
        utterance.postUtteranceDelay = 0.05
        isSpeaking = true
        synthesizer.speak(utterance)

        await withCheckedContinuation { continuation in
            if synthesizer.isSpeaking {
                finishContinuation = continuation
            } else {
                isSpeaking = false
                continuation.resume()
            }
        }
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        if let continuation = finishContinuation {
            finishContinuation = nil
            continuation.resume()
        }
    }

    /// Highest quality voice whose locale matches the practice language.
    static func voice(for language: PracticeLanguage) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { normalised($0.language).hasPrefix(language.code) }
        let sorted = voices.sorted { left, right in
            if left.quality.rawValue != right.quality.rawValue {
                return left.quality.rawValue > right.quality.rawValue
            }
            let leftExact = normalised(left.language).hasPrefix(language.code + "-")
            let rightExact = normalised(right.language).hasPrefix(language.code + "-")
            return leftExact && !rightExact
        }
        return sorted.first ?? AVSpeechSynthesisVoice(language: language.code)
    }

    private static func normalised(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    }
}

private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var onFinish: (@MainActor () -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in onFinish?() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in onFinish?() }
    }
}
