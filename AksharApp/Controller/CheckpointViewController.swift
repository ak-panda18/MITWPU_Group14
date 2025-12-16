import UIKit
import AVFoundation
import Speech

class CheckpointViewController: UIViewController {
    
    @IBOutlet weak var checkpointLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleView: UIView!
    @IBOutlet weak var backView: UIView!
    @IBOutlet weak var textView: UIView!
    @IBOutlet weak var dialogueView: UIView!
    @IBOutlet weak var micButton: UIButton!
    

    var story: Story!
    var checkpointItem: CheckpointItem!
    var nextPageIndex: Int = 0
    var fallbackPageIndex: Int = 0
    

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var attemptCount = 0
    private let maxAttempts = 3
    private var hasPerfectScore = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        imageView.contentMode = .scaleToFill
        imageView.image = UIImage(named: "checkpoint_teddy")
        micButton.setImage(UIImage(systemName: "microphone.fill"), for: .normal)
    }
    
    
    // MARK: - Actions
    
    @IBAction func micTapped(_ sender: UIButton) {
        if audioEngine.isRunning {
            stopListening()
        } else {
            startListening()
        }
    }
    
    @IBAction func backTapped(_ sender: Any) {
        if let nav = navigationController {
            nav.popViewController(animated: false)
        }
    }
    
    @IBAction func continueTapped(_ sender: UIButton) {
        goToNextStoryPage()
    }
    
    
    // MARK: - Speech handling
    
    private func startListening() {
        hasPerfectScore = false
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioSession error: \(error)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                isFinal = result.isFinal
                
                if isFinal {
                    let spokenText = result.bestTranscription.formattedString
                    self.evaluateSpokenText(spokenText)
                }
            }
            
            if error != nil || isFinal {
                self.stopListening()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
            [weak self] (buffer, when) in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("Started Listening")
            micButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        } catch {
            print("Audio Engine couldn't start: \(error)")
        }
    }
    
    private func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        micButton.setImage(UIImage(systemName: "microphone.fill"), for: .normal)
    }
    
    
    // MARK: - Text processing & scoring
    
    private func normalizedWords(from text: String) -> [String] {
        let lowered = text.lowercased()

        // Replace ALL non-letter characters with spaces
        let cleaned = lowered.replacingOccurrences(
            of: "[^a-z]",
            with: " ",
            options: .regularExpression
        )

        // Collapse multiple spaces into one
        let collapsed = cleaned.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        return collapsed
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ")
            .map(String.init)
    }

    
    private func evaluateSpokenText(_ spokenText: String) {
        guard let referenceText = checkpointItem?.text else { return }

        let targetWords = normalizedWords(from: referenceText)
        let spokenWords = normalizedWords(from: spokenText)
        let correctCount = targetWords.filter { target in
            spokenWords.contains { isPhoneticallyClose($0, target) }
        }.count



        let total = max(targetWords.count, 1)
        let accuracy = Float(correctCount) / Float(total)
        print("Accuracy:", accuracy)
        let incorrectCount = colorCheckpointText(usingSpokenWords: spokenWords)

        if accuracy >= 1.0 {
            hasPerfectScore = true
            attemptCount = 0
            micButton.setImage(UIImage(systemName: "checkmark"), for: .normal)

            if isLastCheckpoint() {
                showStoryCompletionAlert()
            } else {
                showCheckpointSuccessAlert()
            }
        }
        else {
            attemptCount += 1
            micButton.setImage(UIImage(systemName: "arrow.trianglehead.clockwise"), for: .normal)
            if attemptCount >= maxAttempts {
                goToFallbackPage()
            } else {
                let percent = Int(accuracy * 100)
                let remaining = maxAttempts - attemptCount
                let alert = UIAlertController(
                    title: "Try again",
                    message: "You read \(percent)% of the words correctly.\nYou have \(remaining) more tries.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }
    
    private func isPhoneticallyClose(_ a: String, _ b: String) -> Bool {
        let aChars = Array(a)
        let bChars = Array(b)

        let lenA = aChars.count
        let lenB = bChars.count

        if abs(lenA - lenB) > 2 { return false }

        var dp = Array(repeating: Array(repeating: 0, count: lenB + 1), count: lenA + 1)

        for i in 0...lenA { dp[i][0] = i }
        for j in 0...lenB { dp[0][j] = j }

        for i in 1...lenA {
            for j in 1...lenB {
                if aChars[i - 1] == bChars[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = min(
                        dp[i - 1][j] + 1,
                        dp[i][j - 1] + 1,
                        dp[i - 1][j - 1] + 1
                    )
                }
            }
        }

        return dp[lenA][lenB] <= 2
    }
    private func colorCheckpointText(usingSpokenWords spokenWords: [String]) -> Int {
        guard let original = checkpointItem?.text else { return 0 }

        let attributed = NSMutableAttributedString(string: original)
        let ns = original as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        let baseFont = checkpointLabel.font ?? UIFont.systemFont(ofSize: 35)
        attributed.addAttributes(
            [.font: baseFont,
             .foregroundColor: UIColor.label],
            range: fullRange
        )
        let targetWords = normalizedWords(from: original)
        let wordRegex = try! NSRegularExpression(pattern: "\\w+", options: [])
        let matches = wordRegex.matches(in: original, range: fullRange)

        let count = min(matches.count, targetWords.count)
        var incorrectCount = 0

        for i in 0..<count {
            let match = matches[i]
            let normalizedTarget = targetWords[i]

            let color: UIColor

            if spokenWords.contains(where: { isPhoneticallyClose($0, normalizedTarget) }) {
                color = .systemGreen
            } else {
                if i >= spokenWords.count {
                    color = .systemGray
                } else {
                    color = .systemRed
                }
                incorrectCount += 1
            }

            attributed.addAttribute(.foregroundColor, value: color, range: match.range)
        }

        if matches.count > count {
            for j in count..<matches.count {
                let match = matches[j]
                attributed.addAttribute(.foregroundColor, value: UIColor.systemGray, range: match.range)
                incorrectCount += 1
            }
        }

        checkpointLabel.attributedText = attributed
        return incorrectCount
    }



    
    
    // MARK: - Navigation
    private func goToNextStoryPage() {
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

            nextVC = vc
        } else {
            let vc = storyboard.instantiateViewController(
                withIdentifier: "LabelReadingVC"
            ) as! LabelReadingViewController

            vc.story = story
            vc.currentIndex = nextPageIndex
            vc.storyTextString = nextPage.text

            nextVC = vc
        }

        if let nav = navigationController {
            var stack = nav.viewControllers
            stack[stack.count - 1] = nextVC
            nav.setViewControllers(stack, animated: false)
        }
    }
    
    private func showStoryCompletionAlert() {
        let alert = UIAlertController(
            title: "Hooray! 🎉",
            message: "Let’s read another one.",
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(
                title: "Go to Library",
                style: .default,
                handler: { [weak self] _ in
                    self?.goToLibrary()
                }
            )
        )

        present(alert, animated: true)
    }
    private func showCheckpointSuccessAlert() {
        let alert = UIAlertController(
            title: "Well done! 🌟",
            message: "Let’s continue reading.",
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(
                title: "Okay",
                style: .default,
                handler: { [weak self] _ in
                    self?.goToNextStoryPage()
                }
            )
        )

        present(alert, animated: true)
    }

    private func goToLibrary() {
        guard let storyboard = storyboard else { return }

        let readingPreviewVC = storyboard.instantiateViewController(
            withIdentifier: "ReadingPreviewVC"
        )

        if let nav = navigationController {
            nav.setViewControllers([readingPreviewVC], animated: true)
        } else {
            present(readingPreviewVC, animated: true)
        }
    }
    
    private func isLastCheckpoint() -> Bool {
        let pages = story.content
        return !(nextPageIndex >= 0 && nextPageIndex < pages.count)
    }
    
    private func fontForStory() -> UIFont {
        guard let difficulty = story?.difficulty.lowercased() else {
            return UIFont.systemFont(ofSize: 30)
        }

        switch difficulty {
        case "level 1":
            return UIFont(name: "ArialMT", size: 32)!

        case "level 2":
            return UIFont(name: "TrebuchetMS", size: 30)!

        case "level 3":
            return UIFont(name: "TimesNewRomanPSMT", size: 30)!

        default:
            return UIFont.systemFont(ofSize: 30)
        }
    }
    private func goToFallbackPage() {
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
            nextVC = vc
        } else {
            let vc = storyboard.instantiateViewController(
                withIdentifier: "LabelReadingVC"
            ) as! LabelReadingViewController
            
            vc.story = story
            vc.currentIndex = index
            vc.storyTextString = page.text
            nextVC = vc
        }
        
        if let nav = navigationController {
            var stack = nav.viewControllers
            stack[stack.count - 1] = nextVC
            nav.setViewControllers(stack, animated: true)
        }
    }
}
