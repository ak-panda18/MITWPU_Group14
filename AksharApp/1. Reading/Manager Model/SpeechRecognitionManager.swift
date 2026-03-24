import Foundation
import Speech
import AVFoundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AksharApp", category: "SpeechRecognitionManager")

final class SpeechRecognitionManager {

    private let audioEngine      = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_IN"))

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask:    SFSpeechRecognitionTask?

    var onWordDetected: ((String) -> Void)?

    // MARK: - Permissions
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                logger.warning("SpeechRecognitionManager: speech permission denied")
            }
        }
        AVAudioApplication.requestRecordPermission { granted in
            if !granted {
                logger.warning("SpeechRecognitionManager: microphone permission denied")
            }
        }
    }

    // MARK: - Start Listening
    func startListening() {
        stopListening()

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            logger.error("SpeechRecognitionManager: speech recognizer unavailable")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("SpeechRecognitionManager: audio session error – \(error)")
            return
        }

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        let recordingFormat = inputNode.inputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            logger.error("SpeechRecognitionManager: invalid microphone format")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let spoken = result.bestTranscription.segments.last?.substring.lowercased() ?? ""
                self.onWordDetected?(spoken)
            }
            if error != nil {
                self.stopListening()
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            logger.error("SpeechRecognitionManager: audio engine failed to start – \(error)")
        }
    }

    // MARK: - Stop Listening
    func stopListening() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
    }

    // MARK: - Restart
    func restart() {
        stopListening()
        startListening()
    }
}
