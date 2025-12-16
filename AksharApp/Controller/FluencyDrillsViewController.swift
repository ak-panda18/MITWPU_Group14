    //
    //  FluencyDrillsViewController.swift
    //  AksharApp
    //
    //  Created by SDC-USER on 09/12/25.
    //

    import UIKit
    import AVFoundation
    import Speech

    class FluencyDrillsViewController: UIViewController, ExerciseReceivesCover, ExerciseResumable, ExerciseProgressReporting {
        
        var exerciseType: ExerciseType?
        var startingIndex: Int? = nil
        var coverWasShown: Bool = false

        @IBOutlet weak var titleLabel: UILabel!
        @IBOutlet weak var scoreLabel: UILabel!
        @IBOutlet weak var timerLabel: UILabel!
        @IBOutlet weak var progressView: UIProgressView!
        @IBOutlet weak var micButton: UIButton!
        @IBOutlet weak var yellowView: UIView!
        @IBOutlet weak var wordLabel: UILabel!
        @IBOutlet weak var nextButton: UIButton!
        
        private var items: [FluencyItem] = []

        var currentIndex = 0
        private var correctCount = 0
        
        private var timer: Timer?
        private var secondsRemaining = 30
        private let totalSeconds = 30
        
        private let audioEngine = AVAudioEngine()
        private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
        private var recognitionTask: SFSpeechRecognitionTask?
        private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        private var isRecording = false
        
        private var sessionActive = true
        private var didScoreCurrentWord = false
        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            styleUI()
            requestPermissions()
            items = FluencyWordsLoader.loadWords()
            items.shuffle()
            currentIndex = startingIndex ?? 0

            if items.isEmpty {
                items = [
                    FluencyItem(speakableText: "Cat"),
                    FluencyItem(speakableText: "Dog"),
                    FluencyItem(speakableText: "Hat")
                ]
            }
            
            loadWord()
            styleSubmitButton()
        }
        override func viewDidLayoutSubviews() {
                super.viewDidLayoutSubviews()
                micButton.layer.cornerRadius = micButton.bounds.height / 2
            }
        func styleSubmitButton() {
            nextButton.configuration = nil
            nextButton.backgroundColor = UIColor(red: 117/255,green: 80/255,blue: 50/255,alpha: 1.0)
            nextButton.setTitleColor(.white, for: .normal)
            nextButton.titleLabel?.font = UIFont(name: "ArialRoundedMTBold", size: 35)
            
            nextButton.layer.cornerRadius = nextButton.bounds.height/2
            nextButton.clipsToBounds = true
        }

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



        func loadWord() {
            guard items.indices.contains(currentIndex) else {
                endSession()
                return
            }

            didScoreCurrentWord = false
            sessionActive = true
            scoreLabel.isHidden = true

            wordLabel.text = items[currentIndex].speakableText
        }

        func requestPermissions() {
            SFSpeechRecognizer.requestAuthorization { _ in }

            AVAudioApplication.requestRecordPermission { granted in
            }
        }


        func resetTimer() {
            timer?.invalidate()
            secondsRemaining = totalSeconds
            timerLabel.text = "30 seconds remaining"
            progressView.progress = 1
            progressView.progressTintColor = .systemBlue
        }

        
        @IBAction func micButtonTapped(_ sender: UIButton) {
            if isRecording {
                stopListening()
            } else {
                resetTimer()
                startListening()
                startTimer()
            }
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

                    self.endSession()
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


        // MARK: - SPEECH RECOGNITION
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

            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                guard let result = result else { return }
                guard self.items.indices.contains(self.currentIndex) else { return }

                let spoken = result.bestTranscription.formattedString.lowercased()
                let expected = self.items[self.currentIndex].speakableText.lowercased()

                if self.didScoreCurrentWord { return }

                if spoken.similar(to: expected) {
                    self.didScoreCurrentWord = true
                    self.correctCount += 1
                    self.currentIndex += 1
                    self.loadWord()
                }
            }

            audioEngine.prepare()
            try? audioEngine.start()

            isRecording = true
            micButton.alpha = 0.7
        }

        
        func showCorrectUI() {
            DispatchQueue.main.async {
                self.stopListening()
                self.timer?.invalidate()

                self.scoreLabel.text = "Correct!"
                self.scoreLabel.textColor = .systemGreen
                self.scoreLabel.isHidden = false

                self.nextButton.isHidden = false
            }
        }
        
        @IBAction func nextButtonTapped(_ sender: Any) {
            correctCount = 0
            currentIndex = 0
            items.shuffle()

            resetTimer()
            loadWord()

            nextButton.isHidden = true
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


         // MARK: - FLOW CONTROL
        
        func endSession() {
            timer?.invalidate()
            audioEngine.stop()

            scoreLabel.text = "You pronounced \(correctCount) words correctly!"
            scoreLabel.textColor = .systemGreen
            scoreLabel.isHidden = false

            nextButton.setTitle("Next", for: .normal)
            nextButton.isHidden = false
        }
        


        @IBAction func backButtonTapped(_ sender: Any) {
            goBackToPhonicsCover()
        }
        
        @IBAction func homeButtonTapped(_ sender: Any) {
            goHomeFromPhonics()
        }
        

    }
    extension String {
        
        func similar(to other: String) -> Bool {
            let a = self.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let b = other.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            if a.contains(b) { return true }
            if b.contains(a) { return true }

            let distance = levenshtein(a, b)
            let maxLen = max(a.count, b.count)
            let similarity = 1.0 - (Double(distance) / Double(maxLen))

            return similarity > 0.65
        }

        private func levenshtein(_ s1: String, _ s2: String) -> Int {
            let a = Array(s1)
            let b = Array(s2)

            if a.isEmpty { return b.count }
            if b.isEmpty { return a.count }

            var dist = Array(
                repeating: Array(repeating: 0, count: b.count + 1),
                count: a.count + 1
            )

            for i in 0...a.count { dist[i][0] = i }
            for j in 0...b.count { dist[0][j] = j }

            if a.count == 0 || b.count == 0 { return max(a.count, b.count) }

            for i in 1...a.count {
                for j in 1...b.count {
                    let cost = (a[i-1] == b[j-1]) ? 0 : 1

                    dist[i][j] = Swift.min(
                        dist[i-1][j] + 1,
                        dist[i][j-1] + 1,
                        dist[i-1][j-1] + cost
                    )
                }
            }

            return dist[a.count][b.count]
        }
    }
