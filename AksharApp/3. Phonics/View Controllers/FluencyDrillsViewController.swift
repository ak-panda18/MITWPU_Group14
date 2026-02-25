//
//  FluencyDrillsViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 09/12/25.
//

import UIKit
import AVFoundation
import Speech

class FluencyDrillsViewController: UIViewController,
                                  ExerciseReceivesCover,
                                  ExerciseResumable {

    // MARK: - Protocol State
    var exerciseType: ExerciseType?
    var startingIndex: Int? = nil
    var coverWasShown: Bool = false

    // MARK: - Outlets
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var micButton: UIButton!
    @IBOutlet weak var yellowView: UIView!
    @IBOutlet weak var wordLabel: UILabel!
    @IBOutlet weak var nextButton: UIButton!

    // MARK: - Internal Data
    private var items: [FluencyItem] = []
    private var localCurrentIndex = 0
    private var localCorrectCount = 0

    // MARK: - Timer
    private var timer: Timer?
    private let totalSeconds = 30
    private var secondsRemaining = 30

    // MARK: - Speech Recognition
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-IN"))

    private var isRecording = false
    private var didScoreCurrentWord = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        styleUI()
        requestPermissions()
        configureGameData()
        styleSubmitButton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        micButton.layer.cornerRadius = micButton.bounds.height / 2
        nextButton.layer.cornerRadius = nextButton.bounds.height / 2
    }

    // MARK: - Configuration
    private func configureGameData() {
            items = BundleDataLoader.shared.load("FluencyDrillsQuestions", as: [FluencyItem].self)
            
            if items.isEmpty {
                items = [
                    FluencyItem(speakableText: "Cat"),
                    FluencyItem(speakableText: "Dog"),
                    FluencyItem(speakableText: "Hat")
                ]
            }
            
            items.shuffle()
            localCurrentIndex = 0
            PhonicsGameplayManager.shared.startSession(
                for: .fluency,
                totalQuestions: items.count,
                startPointer: 0
            )
            loadWord()
        }

    // MARK: - UI Styling
    func styleUI() {
        yellowView.layer.cornerRadius = 16
        yellowView.layer.masksToBounds = true

        progressView.progress = 1
        progressView.trackTintColor = .lightGray
        progressView.progressTintColor = .systemGreen

        timerLabel.text = "30 seconds remaining"
        scoreLabel.isHidden = true
        nextButton.isHidden = true
    }

    func styleSubmitButton() {
        nextButton.configuration = nil
        nextButton.backgroundColor = UIColor(red: 117/255, green: 80/255, blue: 50/255, alpha: 1.0)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.titleLabel?.font = UIFont(name: "ArialRoundedMTBold", size: 35)
        nextButton.layer.cornerRadius = nextButton.bounds.height / 2
        nextButton.clipsToBounds = true
    }

    // MARK: - Word Flow
    func loadWord() {
        if localCurrentIndex >= items.count {
            localCurrentIndex = 0
            items.shuffle()
        }

        didScoreCurrentWord = false
        scoreLabel.isHidden = true
        wordLabel.text = items[localCurrentIndex].speakableText
    }

    // MARK: - Permissions
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioApplication.requestRecordPermission { _ in }
    }

    // MARK: - Timer
    func resetTimer() {
        timer?.invalidate()
        secondsRemaining = totalSeconds
        timerLabel.text = "30 seconds remaining"
        progressView.progress = 1
        progressView.progressTintColor = .systemBlue
    }

    func startTimer() {
        timer?.invalidate()
        secondsRemaining = totalSeconds

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            self.secondsRemaining -= 1

            if self.secondsRemaining < 0 {
                t.invalidate()
                self.stopListening()
                self.timerLabel.text = "Time over!"
                self.progressView.progress = 0
                self.endRound()
                return
            }

            self.timerLabel.text = "\(self.secondsRemaining) seconds remaining"
            self.progressView.progress = Float(self.secondsRemaining) / Float(self.totalSeconds)

            if self.secondsRemaining > 20 {
                self.progressView.progressTintColor = .systemGreen
            } else if self.secondsRemaining > 10 {
                self.progressView.progressTintColor = .systemOrange
            } else {
                self.progressView.progressTintColor = .systemRed
            }
        }
    }

    // MARK: - Actions
    @IBAction func micButtonTapped(_ sender: UIButton) {
        if isRecording {
            stopListening()
        } else {
            resetTimer()
            startListening()
            startTimer()
        }
    }

    @IBAction func nextButtonTapped(_ sender: Any) {
        localCorrectCount = 0
        localCurrentIndex = 0
        items.shuffle()

        resetTimer()
        loadWord()
        nextButton.isHidden = true
    }

    // MARK: - Speech Recognition
    func startListening() {
        audioEngine.stop()
        audioEngine.reset()

        recognitionTask?.cancel()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true)

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, _ in
            guard let self = self,
                  let result = result,
                  self.items.indices.contains(self.localCurrentIndex),
                  !self.didScoreCurrentWord else { return }

            let spoken = result.bestTranscription.formattedString.lowercased()
            let expected = self.items[self.localCurrentIndex].speakableText.lowercased()

            if spoken.isPhoneticMatch(to: expected) {
                
                self.didScoreCurrentWord = true
                
                self.localCorrectCount += 1
                self.localCurrentIndex += 1
                
                PhonicsGameplayManager.shared.recordSuccess()
                PhonicsGameplayManager.shared.recordAttempt()
                
                DispatchQueue.main.async {
                    self.loadWord()
                }
            }
        }

        audioEngine.prepare()
        try? audioEngine.start()

        isRecording = true
        micButton.alpha = 0.7
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.reset()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        isRecording = false
        micButton.alpha = 1
    }

    // MARK: - Round End
    func endRound() {
        timer?.invalidate()
        audioEngine.stop()
        
        scoreLabel.text = "You pronounced \(localCorrectCount) words correctly!"
        scoreLabel.textColor = .systemGreen
        scoreLabel.isHidden = false

        nextButton.setTitle("Next", for: .normal)
        nextButton.isHidden = false
    }

    // MARK: - Navigation
    @IBAction func backButtonTapped(_ sender: Any) {
        PhonicsGameplayManager.shared.endSession()
        goBackToPhonicsCover()
    }

    @IBAction func homeButtonTapped(_ sender: Any) {
        PhonicsGameplayManager.shared.endSession()
        PhonicsGameplayManager.shared.clearCycleProgress()
        goHomeFromPhonics()
    }
}

