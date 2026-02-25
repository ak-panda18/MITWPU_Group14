import UIKit
import AVFoundation
import Speech
import AVKit

class CheckpointViewController: UIViewController {

    // MARK: - Analytics
    var readingSession: ReadingSessionData?
    
    // MARK: - Outlets
    @IBOutlet weak var videoContainerView: UIView!
    @IBOutlet weak var checkpointLabel: UILabel!
    @IBOutlet weak var micButton: UIButton!
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var previousScoresButton: UIButton!
    @IBOutlet weak var titleView: UIView!
    @IBOutlet weak var backView: UIView!
    @IBOutlet weak var textView: UIView!
    @IBOutlet weak var dialogueView: UIView!

    // MARK: - Properties
    var story: Story!
    var checkpointItem: CheckpointItem!
    var nextPageIndex: Int = 0
    var fallbackPageIndex: Int = 0
    var forceRetake: Bool = false

    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-IN"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var stopTimer: Timer?
    private var currentTranscript: String = ""
    private var attemptCount = 0
    private let maxAttempts = 3
    private var hasPerfectScore = false
    private var isPaused = false

    private var checkpointStorageKey: String {
        let storyID = story?.title.replacingOccurrences(of: " ", with: "") ?? "UnknownStory"
        let cleanText = checkpointItem.text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        let checkpointID = String(cleanText.prefix(50))
        
        return "CheckpointCompleted_\(storyID)_\(checkpointID)"
    }
    
    private var attemptsStorageKey: String {
        return "\(checkpointStorageKey)_AttemptsList"
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        playVideoInView()
        setupUI()
        updatePreviousScoresButtonState()
        updateInstructionText()

        if !forceRetake && isCheckpointCompleted() {
            showCompletedState()
        } else {
            showActiveState()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let layer = playerLayer {
            layer.frame = videoContainerView.bounds
            layer.cornerRadius = videoContainerView.layer.cornerRadius
            layer.masksToBounds = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        endReadingSessionIfNeeded()
        hardResetAudio()
    }
    
    // MARK: - Actions
    @IBAction func previousScoresTapped(_ sender: UIButton) {
        guard let scoresVC = storyboard?.instantiateViewController(
            withIdentifier: "PreviousScoresViewController"
        ) as? PreviousScoresViewController else { return }

        scoresVC.originalText = checkpointItem.text
        scoresVC.targetStoryTitle = story?.title ?? "Unknown Story"
        scoresVC.targetCheckpointNumber = (fallbackPageIndex + 1)

        if let sheet = scoresVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersGrabberVisible = true
        }

        present(scoresVC, animated: true)
    }

    @IBAction func micTapped(_ sender: UIButton) {
        if hasPerfectScore {
            goToNextStoryPage()
            return
        }

        if audioEngine.isRunning {
            startGracefulStop()
            playVideoAgain()

        } else {
            stopAndResetVideo()
            startListening()
        }
    }

    @IBAction func backTapped(_ sender: Any) {
        navigationController?.popViewController(animated: false)
    }
    
    @IBAction func homeTapped(_ sender: UIButton) {
         endReadingSessionIfNeeded()

         guard
             let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
             let window = windowScene.windows.first,
             let storyboard = self.storyboard,
             let homeVC = storyboard.instantiateViewController(
                 withIdentifier: "HomeVC"
             ) as? HomeViewController
         else { return }

         let nav = UINavigationController(rootViewController: homeVC)
         nav.setNavigationBarHidden(true, animated: false)

         window.rootViewController = nav
         window.makeKeyAndVisible()
     }

    @IBAction func continueTapped(_ sender: UIButton) {
        goToNextStoryPage()
    }

}

// MARK: - Video Playback
private extension CheckpointViewController {
    func playVideoInView() {
        guard let path = Bundle.main.path(forResource: "checkpointTeddy", ofType: "mp4") else { return }
        player = AVPlayer(url: URL(fileURLWithPath: path))
        playerLayer = AVPlayerLayer(player: player)
        player?.isMuted = true
        playerLayer?.frame = videoContainerView.bounds
        playerLayer?.videoGravity = .resizeAspectFill
        if let playerLayer {
            videoContainerView.layer.addSublayer(playerLayer)
        }
        player?.play()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loopVideo),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )
    }
    
    func stopAndResetVideo() {
        player?.pause()
        player?.seek(to: .zero)
    }
    
    func playVideoAgain() {
        player?.seek(to: .zero)
        player?.play()
    }
    
    @objc func loopVideo() {
        player?.seek(to: .zero)
        player?.play()
    }
}

// MARK: - UI Setup & State
private extension CheckpointViewController {
    func setupUI() {
        titleView.layer.cornerRadius = 50
        titleView.layer.borderColor = UIColor.systemYellow.cgColor
        titleView.layer.borderWidth = 3.0

        backView.layer.cornerRadius = 25
        backView.layer.borderColor = UIColor.systemYellow.cgColor
        backView.layer.borderWidth = 3.0

        textView.layer.cornerRadius = 25
        textView.layer.borderColor = UIColor.systemYellow.cgColor
        textView.layer.borderWidth = 1.0

        dialogueView.layer.cornerRadius = 12
        dialogueView.layer.shadowColor = UIColor.systemYellow.cgColor
        dialogueView.layer.shadowOpacity = 0.3
        dialogueView.layer.shadowOffset = CGSize(width: 0, height: 5)
        dialogueView.layer.shadowRadius = 10
        dialogueView.layer.masksToBounds = false

        checkpointLabel.text = checkpointItem.text
        checkpointLabel.font = fontForStory()
        checkpointLabel.numberOfLines = 0

        micButton.setImage(UIImage(systemName: "microphone.fill"), for: .normal)

        previousScoresButton.layer.cornerRadius = previousScoresButton.frame.height / 2
        previousScoresButton.clipsToBounds = true
    }
    
    func updateInstructionText() {
        let remaining = maxAttempts - attemptCount
        if attemptCount == 0 {
            instructionLabel.text = "Read this out for me.\nYou have 3 tries!"
        } else if remaining == 1 {
            instructionLabel.text = "1 try left.\n You've got this!"
        } else {
            instructionLabel.text = "\(remaining) tries left.\n Let's try again!"
        }
        instructionLabel.textAlignment = .center
    }
    
    func showCompletedState() {
            hasPerfectScore = true
            micButton.setImage(UIImage(systemName: "arrow.right.circle.fill"), for: .normal)
            micButton.tintColor = .systemGreen
            
            let allWordsInText = checkpointItem.text.gradableWords
            
            let attributed = checkpointItem.text.colored(
                matching: allWordsInText,
                font: checkpointLabel.font ?? UIFont.systemFont(ofSize: 30)
            )
            
            checkpointLabel.attributedText = attributed
        }
    
    func showActiveState() {
        hasPerfectScore = false
        attemptCount = 0
        micButton.setImage(UIImage(systemName: "microphone.fill"), for: .normal)
        micButton.tintColor = .systemBlue
        checkpointLabel.textColor = .label
        checkpointLabel.attributedText = nil
        checkpointLabel.text = checkpointItem.text
    }
}

// MARK: - Speech Recognition
private extension CheckpointViewController {
    func startListening() {
            checkpointLabel.attributedText = nil
            checkpointLabel.text = checkpointItem.text
            checkpointLabel.textColor = .label
            
            hasPerfectScore = false
            currentTranscript = ""
            hardResetAudio()

            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                print("Audio Session error: \(error)")
            }

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            if #available(iOS 13, *) {
                recognitionRequest.requiresOnDeviceRecognition = false
            }

            let inputNode = audioEngine.inputNode
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }

                if let result = result {
                     self.currentTranscript = result.bestTranscription.formattedString

                     if result.isFinal {
                         self.stopTimer?.invalidate()
                         self.stopTimer = nil

                         self.hardResetAudio()
                         self.evaluateSpokenText(self.currentTranscript)
                     }
                 }

                 if error != nil {
                     self.hardResetAudio()
                     self.micButton.setImage(UIImage(systemName: "microphone.fill"), for: .normal)
                     self.micButton.isEnabled = true
                 }
             }

            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try? audioEngine.start()

            micButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        }
    
    func startGracefulStop() {
        micButton.isEnabled = false
        recognitionRequest?.endAudio()
        stopTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.hardResetAudio()
            self.evaluateSpokenText(self.currentTranscript)
        }
    }
    
    func hardResetAudio() {
        stopTimer?.invalidate()
        stopTimer = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

// MARK: - Evaluation & Scoring
private extension CheckpointViewController {
    
    func evaluateSpokenText(_ spokenText: String) {
        stopTimer?.invalidate()
        stopTimer = nil
        
        let normalizedSpoken = spokenText.allWords.joined(separator: " ") // simple clean
        let cleanText = spokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanText.isEmpty else {
            micButton.setImage(UIImage(systemName: "microphone.fill"), for: .normal)
            micButton.isEnabled = true
            return
        }
        
        guard let referenceText = checkpointItem?.text else { return }
        
        let targetWords = referenceText.gradableWords
        let spokenWords = normalizedSpoken.allWords
        
        guard spokenWords.count >= 1 else { return }
        
        let attributed = referenceText.colored(matching: spokenWords, font: checkpointLabel.font)
        checkpointLabel.attributedText = attributed
        
        var correctCount = 0
        attributed.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: attributed.length)) { value, range, _ in
            if let color = value as? UIColor, color == .systemGreen {
                let fragment = (attributed.string as NSString).substring(with: range)
                correctCount += fragment.gradableWords.count
            }
        }
        
        let total = max(targetWords.count, 1)
        let rawAccuracy = Double(correctCount) / Double(total)
        let accuracy = min(rawAccuracy, 1.0)
        let percent = Int(accuracy * 100)
        
        saveAttempt(accuracy: percent, spokenWords: spokenWords)
        saveCheckpointAccuracy(accuracy)
        
        let passThreshold: Double = 0.80
        
        if accuracy >= passThreshold {
            hasPerfectScore = true
            attemptCount = 0
            saveCheckpointCompletion()
            micButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
            micButton.tintColor = .systemGreen
            
            if isLastCheckpoint() {
                showStoryCompletionAlert()
            } else {
                showCheckpointSuccessAlert()
            }
        } else {
            attemptCount += 1
            updateInstructionText()
            micButton.setImage(UIImage(systemName: "arrow.trianglehead.clockwise"), for: .normal)
            micButton.isEnabled = true
            
            if attemptCount >= maxAttempts {
                presentCustomAlert(
                    title: "Let's practice",
                    message: "Let's practice some more and try again!",
                    buttonText: "Continue",
                    image: UIImage(named: "mascot_encouraging")
                ) { [weak self] in
                    self?.goToFallbackPage()
                }
            } else {
                let remaining = maxAttempts - attemptCount
                presentCustomAlert(
                    title: "Keep Going!",
                    message: "You read \(percent)% correctly.\nYou have \(remaining) more tries.",
                    buttonText: "Try Again",
                    image: UIImage(named: "mascot_encouraging")
                ) { }
            }
        }
    }
}

// MARK: - Checkpoint Persistence
private extension CheckpointViewController {

    func isCheckpointCompleted() -> Bool {
        return StoryManager.shared.isCheckpointCompleted(
            storyId: story.id,
            checkpointText: checkpointItem.text
        )
    }
    
    func saveCheckpointCompletion() {
        StoryManager.shared.markCheckpointCompleted(
            storyId: story.id,
            checkpointText: checkpointItem.text
        )
    }
    
    func saveAttempt(accuracy: Int, spokenWords: [String]) {
            let newAttempt = CheckpointAttempt(
                storyTitle: story?.title ?? "Unknown Story",
                checkpointNumber: (fallbackPageIndex + 1),
                accuracy: accuracy,
                spokenWords: spokenWords,
                timestamp: Date()
            )
            
            CheckpointHistoryManager.shared.save(attempt: newAttempt)

            updatePreviousScoresButtonState()
        }
    
    func updatePreviousScoresButtonState() {
        let title = story?.title ?? ""
        let number = fallbackPageIndex + 1
        
        let history = CheckpointHistoryManager.shared.getAttempts(for: title, checkpointNumber: number)
        
        let hasPreviousScores = !history.isEmpty
        previousScoresButton.isEnabled = hasPreviousScores
        previousScoresButton.alpha = hasPreviousScores ? 1.0 : 0.4
    }
}
// MARK: - Analytics
private extension CheckpointViewController {
    func saveCheckpointAccuracy(_ accuracy: Double) {
        let result = ReadingCheckpointResultData(
            id: UUID(),
            date: Date(),
            storyId: story.id,
            childId: "default_child",
            accuracy: accuracy * 100,
            checkpointText: checkpointItem.text
        )

        AnalyticsStore.shared.appendCheckpointResult(result)
        print("Checkpoint accuracy saved:", result.accuracy)
    }
    
    func endReadingSessionIfNeeded() {
        guard let session = readingSession else { return }
        
        let endTime = Date()
        AnalyticsStore.shared.updateReadingSessionEnd(
            sessionId: session.id,
            endTime: endTime
        )
        readingSession?.endTime = endTime
        print("Reading session ended/updated")
    }
}

// MARK: - Navigation
private extension CheckpointViewController {
    func goToNextStoryPage() {
        let pages = story.content
        guard nextPageIndex >= 0, nextPageIndex < pages.count else {
            showStoryCompletionAlert()
            return
        }

        let nextPage = pages[nextPageIndex]
        guard let storyboard = self.storyboard else { return }

        let nextVC: UIViewController
        if let imgName = nextPage.imageURL, !imgName.isEmpty {
            let vc = storyboard.instantiateViewController(
                withIdentifier: "ImageLabelReadingVC"
            ) as! ImageLabelReadingViewController
            vc.story = story
            vc.currentIndex = nextPageIndex
            vc.storyTextString = nextPage.text
            vc.imageName = imgName
            vc.readingSession = self.readingSession
            nextVC = vc
        } else {
            let vc = storyboard.instantiateViewController(
                withIdentifier: "LabelReadingVC"
            ) as! LabelReadingViewController
            vc.story = story
            vc.currentIndex = nextPageIndex
            vc.storyTextString = nextPage.text
            vc.readingSession = self.readingSession
            nextVC = vc
        }

        if let nav = navigationController {
            nav.popViewController(animated: false)
            nav.pushViewController(nextVC, animated: true)
        }
    }
    
    func goToFallbackPage() {
        let pages = story.content
        let index = max(0, min(fallbackPageIndex, pages.count - 1))
        let page = pages[index]
        guard let storyboard = self.storyboard else { return }

        let nextVC: UIViewController
        if let imgName = page.imageURL, !imgName.isEmpty {
            let vc = storyboard.instantiateViewController(
                withIdentifier: "ImageLabelReadingVC"
            ) as! ImageLabelReadingViewController
            vc.story = story
            vc.currentIndex = index
            vc.storyTextString = page.text
            vc.imageName = imgName
            vc.readingSession = self.readingSession
            nextVC = vc
        } else {
            let vc = storyboard.instantiateViewController(
                withIdentifier: "LabelReadingVC"
            ) as! LabelReadingViewController
            vc.story = story
            vc.currentIndex = index
            vc.storyTextString = page.text
            vc.readingSession = self.readingSession
            nextVC = vc
        }

        if let nav = navigationController {
            nav.popViewController(animated: false)
            nav.pushViewController(nextVC, animated: true)
        }
    }
    
    func goToLibrary() {
        endReadingSessionIfNeeded()

        guard let nav = navigationController else { return }
        for vc in nav.viewControllers {
            if vc is ReadingPreviewViewController {
                nav.popToViewController(vc, animated: true)
                return
            }
        }
        nav.popToRootViewController(animated: true)
    }
    
    func isLastCheckpoint() -> Bool {
        let pages = story.content
        return !(nextPageIndex >= 0 && nextPageIndex < pages.count)
    }
}

// MARK: - Alerts
private extension CheckpointViewController {
    func presentCustomAlert(
        title: String,
        message: String,
        buttonText: String,
        image: UIImage?,
        completion: @escaping () -> Void
    ) {
        guard let alertVC = storyboard?.instantiateViewController(
            withIdentifier: "CustomAlertVC"
        ) as? CustomAlertViewController else { return }

        alertVC.alertTitle = title
        alertVC.alertMessage = message
        alertVC.buttonText = buttonText
        alertVC.alertImage = image
        alertVC.onDismiss = completion
        alertVC.modalPresentationStyle = .overCurrentContext
        alertVC.modalTransitionStyle = .crossDissolve

        present(alertVC, animated: true)
    }
    
    func showCheckpointSuccessAlert() {
        presentCustomAlert(
            title: "Well done!",
            message: "You read that perfectly!",
            buttonText: "Continue",
            image: UIImage(named: "success_mascot")
        ) { [weak self] in
            self?.goToNextStoryPage()
        }
    }
    
    func showStoryCompletionAlert() {
            presentCustomAlert(
                title: "Hooray! ",
                message: "You finished the story!",
                buttonText: "Go to Library",
                image: UIImage(named: "mascot_celebrating")
            ) { [weak self] in
                
                if let currentStory = self?.story {
                    StoryManager.shared.saveProgress(
                        storyId: currentStory.id,
                        pageIndex: (currentStory.content.count - 1),
                        didComplete: true
                    )
                }
                
                self?.goToLibrary()
            }
        }
}

// MARK: - Typography
private extension CheckpointViewController {
    func fontForStory() -> UIFont {
        guard let difficulty = story?.difficulty.lowercased() else {
            return UIFont.systemFont(ofSize: 30)
        }
        switch difficulty {
        case "level 1":
            return UIFont(name: "ArialMT", size: 32) ?? UIFont.systemFont(ofSize: 32)
        case "level 2":
            return UIFont(name: "TrebuchetMS", size: 30) ?? UIFont.systemFont(ofSize: 30)
        case "level 3":
            return UIFont(name: "TimesNewRomanPSMT", size: 30) ?? UIFont.systemFont(ofSize: 30)
        default:
            return UIFont.systemFont(ofSize: 30)
        }
    }
}
