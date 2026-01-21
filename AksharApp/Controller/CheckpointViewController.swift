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
    private let ignorableWords: Set<String> = [
            "a", "an", "the",
            "and", "but", "or", "so", "if", "because",
            "to", "of", "in", "on", "at", "by", "for", "from", "with", "up", "out",
            "it", "he", "she", "they", "we", "i", "you", "me", "my", "this", "that",
            "is", "am", "are", "was", "were", "be", "been",
            "has", "have", "had", "do", "does", "did",
            "can", "will", "would", "could", "should"
        ]

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
        } else {
            if audioEngine.isRunning {
                startGracefulStop()
            } else {
                startListening()
            }
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
        _ = colorCheckpointText(usingSpokenWords: normalizedWords(from: checkpointItem.text))
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
    func preprocessSpokenText(_ text: String) -> String {
            var processed = text.lowercased()
            let replacements = [
                "i have": "i've",
                "we have": "we've",
                "you have": "you've",
                "they have": "they've",
                "do not": "don't",
                "did not": "didn't",
                "can not": "can't",
                "cannot": "can't",
                "will not": "won't",
                "is not": "isn't",
                "it is": "it's",
                "that is": "that's",
                "what is": "what's",
                "where is": "where's"
            ]
            for (pattern, template) in replacements {
                processed = processed.replacingOccurrences(of: pattern, with: template)
            }
            return processed
        }
 
    func evaluateSpokenText(_ spokenText: String) {
            stopTimer?.invalidate()
            stopTimer = nil
            
            let normalizedText = preprocessSpokenText(spokenText)
            let cleanText = spokenText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !cleanText.isEmpty else {
                micButton.setImage(UIImage(systemName: "microphone.fill"), for: .normal)
                micButton.isEnabled = true
                return
            }

            guard let referenceText = checkpointItem?.text else { return }
            let targetWords = getGradableWords(from: referenceText)
            let spokenWords = getAllWords(from: normalizedText)
            
            guard spokenWords.count >= 1 else { return }

            let correctCount = colorCheckpointText(usingSpokenWords: spokenWords)
            
            let total = max(targetWords.count, 1)
            let rawAccuracy = Double(correctCount) / Double(total)
            let accuracy = min(rawAccuracy, 1.0)
            
            let percent = Int(accuracy * 100)
            
            saveAttempt(accuracy: percent, spokenWords: spokenWords)
            saveCheckpointAccuracy(accuracy)
            
            let passThreshold: Double = total <= 3 ? 0.80 : 0.80
            
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
    
    func getGradableWords(from text: String) -> [String] {
            let clean = text
                .lowercased()
                .replacingOccurrences(of: "[^a-z\\s]", with: "", options: .regularExpression)

            return clean
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty && !ignorableWords.contains($0) }
        }
        
        func getAllWords(from text: String) -> [String] {
            let clean = text
                .lowercased()
                .replacingOccurrences(of: "[^a-z\\s]", with: "", options: .regularExpression)

            return clean
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty } 
        }
    
    func normalizedWords(from text: String) -> [String] {
        let clean = text
            .lowercased()
            .replacingOccurrences(of: "[^a-z\\s]", with: "", options: .regularExpression)

        return clean
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty && !ignorableWords.contains($0) }
    }
    
    
    func colorCheckpointText(usingSpokenWords spokenWords: [String]) -> Int {
            guard let original = checkpointItem?.text else { return 0 }
            let attributed = NSMutableAttributedString(string: original)
            let fullRange = NSRange(location: 0, length: (original as NSString).length)
            let baseFont = checkpointLabel.font ?? UIFont.systemFont(ofSize: 35)
            attributed.addAttributes(
                [.font: baseFont, .foregroundColor: UIColor.systemGray],
                range: fullRange
            )
            let wordRegex = try! NSRegularExpression(pattern: "[\\w']+", options: [])
            let matches = wordRegex.matches(in: original, range: fullRange)

            var spokenIndex = 0
            var correctCount = 0
            
            for (i, match) in matches.enumerated() {
                let wordRange = match.range
                let wordText = (original as NSString).substring(with: wordRange)
                let cleanWord = wordText.lowercased()
                
                let searchLimit = min(spokenIndex + 5, spokenWords.count)
                var foundMatch = false
                var matchIndex = -1

                for j in spokenIndex..<searchLimit {
                    if isRelaxedMatch(spoken: spokenWords[j], target: cleanWord) {
                        matchIndex = j
                        foundMatch = true
                        break
                    }
                }

                if foundMatch {
                    attributed.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: wordRange)
                    let rawWord = cleanWord.replacingOccurrences(of: "'", with: "")
                    if !ignorableWords.contains(rawWord) {
                        correctCount += 1
                    }
                    spokenIndex = matchIndex + 1
                } else {
                    if spokenIndex < spokenWords.count {
                        let currentSpoken = spokenWords[spokenIndex]
                        var isNextWord = false
                        if i + 1 < matches.count {
                            let nextRange = matches[i+1].range
                            let nextText = (original as NSString).substring(with: nextRange).lowercased()
                            if isRelaxedMatch(spoken: currentSpoken, target: nextText) {
                                isNextWord = true
                            }
                        }
                        
                        if !isNextWord {
                             attributed.addAttribute(.foregroundColor, value: UIColor.systemRed, range: wordRange)
                             spokenIndex += 1
                        }
                    }
                }
            }
            
            checkpointLabel.attributedText = attributed
            return correctCount
        }
    
    func isRelaxedMatch(spoken: String, target: String) -> Bool {
            let s = spoken.lowercased()
            let t = target.lowercased()

            if s == t { return true }
            if (s.first == "w" && t.first == "v") || (s.first == "v" && t.first == "w") {
                let sDrop = s.dropFirst()
                let tDrop = t.dropFirst()
                if sDrop == tDrop { return true }
                if levenshteinDistance(String(sDrop), String(tDrop)) <= 1 { return true }
            }

            if s.hasPrefix(t) || t.hasPrefix(s) {
                return true
            }

            let distance = levenshteinDistance(s, t)
            let maxLen = max(s.count, t.count)
            guard maxLen > 0 else { return false }
            if t.hasPrefix("wh") {
                if s.hasPrefix("w") || s.hasPrefix("v") {
                    if distance <= 2 { return true }
                }
            }

            let similarity = 1.0 - Double(distance) / Double(maxLen)
            if t.starts(with: "w") {
                if maxLen <= 4 && distance <= 1 { return true }
            }
            
            switch maxLen {
            case 1...3:
                return similarity >= 0.7
            case 4...6:
                return similarity >= 0.65
            default:
                return similarity >= 0.6
            }
        }
    
    func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let lenA = aChars.count
        let lenB = bChars.count

        if lenA == 0 { return lenB }
        if lenB == 0 { return lenA }

        var dp = Array(repeating: Array(repeating: 0, count: lenB + 1), count: lenA + 1)
        for i in 0...lenA { dp[i][0] = i }
        for j in 0...lenB { dp[0][j] = j }

        for i in 1...lenA {
            for j in 1...lenB {
                if aChars[i - 1] == bChars[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + 1)
                }
            }
        }
        return dp[lenA][lenB]
    }
}

// MARK: - Checkpoint Persistence
private extension CheckpointViewController {
    func isCheckpointCompleted() -> Bool {
        return UserDefaults.standard.bool(forKey: checkpointStorageKey)
    }
    
    func saveCheckpointCompletion() {
        UserDefaults.standard.set(true, forKey: checkpointStorageKey)
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

        var localAttempts = loadAttempts()
        localAttempts.insert(newAttempt, at: 0)
        if localAttempts.count > 3 {
            localAttempts = Array(localAttempts.prefix(3))
        }
        if let encodedLocal = try? JSONEncoder().encode(localAttempts) {
            UserDefaults.standard.set(encodedLocal, forKey: attemptsStorageKey)
        }
        updatePreviousScoresButtonState()
    }
    
    func loadAttempts() -> [CheckpointAttempt] {
        if let data = UserDefaults.standard.data(forKey: attemptsStorageKey),
           let attempts = try? JSONDecoder().decode([CheckpointAttempt].self, from: data) {
            return attempts
        }
        return []
    }
    
    func updatePreviousScoresButtonState() {
        let hasPreviousScores = !loadAttempts().isEmpty
        
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
        print("📊 Checkpoint accuracy saved:", result.accuracy)
    }
    
    func endReadingSessionIfNeeded() {
        guard let session = readingSession else { return }
        
        let endTime = Date()
        AnalyticsStore.shared.updateReadingSessionEnd(
            sessionId: session.id,
            endTime: endTime
        )
        readingSession?.endTime = endTime
        print("📕 Reading session ended/updated")
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
            title: "Well done 🌟",
            message: "You read that perfectly!",
            buttonText: "Continue",
            image: UIImage(named: "success_mascot")
        ) { [weak self] in
            self?.goToNextStoryPage()
        }
    }
    
    func showStoryCompletionAlert() {
        presentCustomAlert(
            title: "Hooray! 🎉",
            message: "You finished the story!",
            buttonText: "Go to Library",
            image: UIImage(named: "mascot_celebrating")
        ) { [weak self] in
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
