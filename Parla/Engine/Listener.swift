import AVFoundation
import Foundation
import Speech

/// Live microphone transcription with the on-device transcriber.
///
/// Feeds microphone audio into `SpeechAnalyzer`, publishes a live partial
/// transcript, and calls `onUtterance` once the speaker has paused long enough
/// for their sentence to count as finished.
@MainActor
@Observable
final class Listener {
    enum Failure: LocalizedError {
        case noAudioFormat
        case microphoneDenied
        case speechDenied
        case engineStart(String)

        var errorDescription: String? {
            switch self {
            case .noAudioFormat: "The transcriber could not agree on an audio format."
            case .microphoneDenied: "Parla needs the microphone to hear you."
            case .speechDenied: "Parla needs speech recognition to write down what you say."
            case .engineStart(let reason): "The microphone would not start: \(reason)"
            }
        }
    }

    private let audio = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var feed: AsyncStream<AnalyzerInput>.Continuation?
    private var tap: MicTap?
    private var tapInstalled = false
    private var analysisTask: Task<Void, Never>?
    private var resultsTask: Task<Void, Never>?
    private var watcherTask: Task<Void, Never>?

    /// Text of the current, not-yet-finished utterance.
    private var committed = ""
    private var tentative = ""
    private var lastChange = Date.distantPast

    private(set) var partial = ""
    private(set) var level: Double = 0
    private(set) var isRunning = false
    private(set) var isMuted = false

    /// Silence of this length closes an utterance.
    var pauseSeconds: Double = 1.25
    var onUtterance: (@MainActor (String) -> Void)?

    func start(language: PracticeLanguage) async throws {
        guard !isRunning else { return }
        try await requestPermissions()

        let transcriber = SpeechTranscriber(
            locale: language.locale,
            transcriptionOptions: [.etiquetteReplacements],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw Failure.noAudioFormat
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.prepareToAnalyze(in: format)

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        feed = continuation
        self.transcriber = transcriber
        self.analyzer = analyzer
        configureSession()

        analysisTask = Task { [weak self] in
            do {
                try await analyzer.start(inputSequence: stream)
            } catch {
                await MainActor.run { self?.isRunning = false }
            }
        }
        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    await MainActor.run { self?.consume(result) }
                }
            } catch {
                await MainActor.run { self?.isRunning = false }
            }
        }
        watcherTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(120))
                await MainActor.run { self?.closeIfSilent() }
            }
        }

        let tap = MicTap(
            inputFormat: audio.inputNode.inputFormat(forBus: 0),
            analyzerFormat: format,
            continuation: continuation,
            onLevel: { [weak self] value in
                Task { @MainActor in self?.level = value }
            }
        )
        self.tap = tap
        audio.inputNode.installTap(onBus: 0, bufferSize: 2048, format: tap.inputFormat) { buffer, _ in
            tap.handle(buffer)
        }
        tapInstalled = true

        audio.prepare()
        do {
            try audio.start()
        } catch {
            removeTapIfNeeded()
            Log.speech.error("microphone did not start: \(error.localizedDescription, privacy: .public)")
            throw Failure.engineStart(error.localizedDescription)
        }
        isRunning = true
        Log.speech.info("listening in \(language.code, privacy: .public) at \(format.sampleRate, privacy: .public) Hz")
    }

    /// Ignore the microphone while the tutor is talking.
    func setMuted(_ muted: Bool) {
        guard muted != isMuted else { return }
        isMuted = muted
        committed = ""
        tentative = ""
        partial = ""
        level = 0
    }

    func stop() async {
        isRunning = false
        watcherTask?.cancel()
        watcherTask = nil
        resultsTask?.cancel()
        resultsTask = nil
        removeTapIfNeeded()
        if audio.isRunning { audio.stop() }
        feed?.finish()
        feed = nil
        tap = nil
        analysisTask?.cancel()
        analysisTask = nil
        if let analyzer {
            await analyzer.cancelAndFinishNow()
        }
        analyzer = nil
        transcriber = nil
        deactivateSession()
        committed = ""
        tentative = ""
        partial = ""
        level = 0
    }

    private func removeTapIfNeeded() {
        guard tapInstalled else { return }
        audio.inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }

    // MARK: - Transcript

    private func consume(_ result: SpeechTranscriber.Result) {
        guard !isMuted else { return }
        let text = String(result.text.characters)
        if result.isFinal {
            committed += text
            tentative = ""
        } else {
            tentative = text
        }
        let combined = (committed + tentative).trimmingCharacters(in: .whitespacesAndNewlines)
        guard combined != partial else { return }
        partial = combined
        if !combined.isEmpty { lastChange = Date.now }
    }

    private func closeIfSilent() {
        guard isRunning, !isMuted else { return }
        let text = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard Date.now.timeIntervalSince(lastChange) >= pauseSeconds else { return }
        committed = ""
        tentative = ""
        partial = ""
        level = 0
        onUtterance?(text)
    }

    // MARK: - Permissions and session

    private func requestPermissions() async throws {
        #if os(iOS)
        let microphone = await AVAudioApplication.requestRecordPermission()
        #else
        let microphone = await AVCaptureDevice.requestAccess(for: .audio)
        #endif
        guard microphone else { throw Failure.microphoneDenied }

        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speech else { throw Failure.speechDenied }
    }

    private func configureSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        // The voiceChat mode brings echo cancellation with it, so the tutor's
        // own voice is not transcribed back into the conversation.
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .defaultToSpeaker])
        try? session.setActive(true)
        #endif
    }

    private func deactivateSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }
}

/// Owns the audio converter and pushes microphone buffers into the analyser's
/// input stream. Only ever touched on the audio thread.
private final class MicTap: @unchecked Sendable {
    let inputFormat: AVAudioFormat
    private let analyzerFormat: AVAudioFormat
    private let converter: AVAudioConverter?
    private let continuation: AsyncStream<AnalyzerInput>.Continuation
    private let onLevel: @Sendable (Double) -> Void

    init(
        inputFormat: AVAudioFormat,
        analyzerFormat: AVAudioFormat,
        continuation: AsyncStream<AnalyzerInput>.Continuation,
        onLevel: @escaping @Sendable (Double) -> Void
    ) {
        self.inputFormat = inputFormat
        self.analyzerFormat = analyzerFormat
        self.continuation = continuation
        self.onLevel = onLevel
        let needsConversion = inputFormat.sampleRate != analyzerFormat.sampleRate
            || inputFormat.channelCount != analyzerFormat.channelCount
            || inputFormat.commonFormat != analyzerFormat.commonFormat
        self.converter = needsConversion ? AVAudioConverter(from: inputFormat, to: analyzerFormat) : nil
    }

    func handle(_ buffer: AVAudioPCMBuffer) {
        let loudness = Self.loudness(of: buffer)
        onLevel(min(Double(loudness) * 6, 1))

        guard let converter else {
            continuation.yield(AnalyzerInput(buffer: buffer))
            return
        }
        let ratio = analyzerFormat.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 512
        guard let output = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return }
        var supplied = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        guard output.frameLength > 0 else { return }
        continuation.yield(AnalyzerInput(buffer: output))
    }

    private static func loudness(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var sum: Float = 0
        var index = 0
        var counted = 0
        while index < frames {
            let sample = channels[index]
            sum += sample * sample
            index += 8
            counted += 1
        }
        return sqrt(sum / Float(max(counted, 1)))
    }
}
