import AVFoundation

final class SpeechManager: NSObject {

    private let synthesizer = AVSpeechSynthesizer()

    @MainActor var onSpeechFinished: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Speak
    @MainActor
    func speak(text: String, language: String = "en-AU", rate: Float = 0.35) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = rate
        synthesizer.speak(utterance)
    }

    // MARK: - Controls
    @MainActor func pause()  { synthesizer.pauseSpeaking(at: .word) }
    @MainActor func resume() { synthesizer.continueSpeaking() }
    @MainActor func stop()   { synthesizer.stopSpeaking(at: .immediate) }
    @MainActor func isSpeaking() -> Bool { synthesizer.isSpeaking }
    @MainActor func isPaused()   -> Bool { synthesizer.isPaused }
}

// MARK: - AVSpeechSynthesizerDelegate
extension SpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.onSpeechFinished?()
        }
    }
}
