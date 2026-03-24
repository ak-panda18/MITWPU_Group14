import UIKit

class FluencyDrillsViewController: UIViewController,
                                   ExerciseDependencyReceivable, ExerciseReceivesCover,
                                   ExerciseSTTReceivable, ExerciseResumable {

    var phonicsGameplayManager: PhonicsGameplayManager!
    var bundleDataLoader: BundleDataLoader!

    var speechRecognitionManager: SpeechRecognitionManager!
    var gameTimerManager: GameTimerManager!

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
    private var roundEnded = false

    // MARK: - Speech Recognition state
    private var isRecording = false
    private var didScoreCurrentWord = false

    // MARK: - Lifecycle
    private func verifyDependencies() {
        assert(phonicsGameplayManager != nil, "phonicsGameplayManager was not injected into \(type(of: self))")
        assert(bundleDataLoader != nil, "bundleDataLoader was not injected into \(type(of: self))")
        assert(speechRecognitionManager != nil, "speechRecognitionManager was not injected into \(type(of: self))")
        assert(gameTimerManager != nil, "gameTimerManager was not injected into \(type(of: self))")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        verifyDependencies()
        styleUI()
        configureGameData()
        styleSubmitButton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        micButton.layer.cornerRadius  = micButton.bounds.height / 2
        nextButton.layer.cornerRadius = nextButton.bounds.height / 2
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        gameTimerManager.stop()
        speechRecognitionManager.stopListening()
    }

    // MARK: - Configuration
    private func configureGameData() {
        items = bundleDataLoader.load("FluencyDrillsQuestions", as: [FluencyItem].self)

        if items.isEmpty {
            items = [
                FluencyItem(speakableText: "Cat"),
                FluencyItem(speakableText: "Dog"),
                FluencyItem(speakableText: "Hat")
            ]
        }

        items.shuffle()
        localCurrentIndex = 0
        phonicsGameplayManager.startSession(for: .fluency, totalQuestions: items.count, startPointer: 0)
        loadWord()
    }

    // MARK: - UI Styling
    func styleUI() {
        yellowView.layer.cornerRadius = 16
        yellowView.layer.masksToBounds = true

        progressView.progress         = 1
        progressView.trackTintColor   = .lightGray
        progressView.progressTintColor = .systemGreen

        timerLabel.text     = "30 seconds remaining"
        scoreLabel.isHidden = true
        nextButton.isHidden = true
    }

    func styleSubmitButton() {
        nextButton.configuration    = nil
        nextButton.backgroundColor  = UIColor(red: 117/255, green: 80/255, blue: 50/255, alpha: 1.0)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.titleLabel?.font = UIFont(name: "ArialRoundedMTBold", size: 35)
        nextButton.layer.cornerRadius = nextButton.bounds.height / 2
        nextButton.clipsToBounds    = true
    }

    // MARK: - Word Flow
    func loadWord() {
        if localCurrentIndex >= items.count {
            localCurrentIndex = 0
            items.shuffle()
        }
        didScoreCurrentWord = false
        scoreLabel.isHidden = true
        wordLabel.text      = items[localCurrentIndex].speakableText
    }

    // MARK: - Timer
    func resetTimer() {
        gameTimerManager.reset()
        timerLabel.text               = "30 seconds remaining"
        progressView.progress         = 1
        progressView.progressTintColor = .systemBlue
    }

    func startTimer() {
        gameTimerManager.onTick = { [weak self] seconds in
            guard let self else { return }
            DispatchQueue.main.async {
                self.timerLabel.text    = "\(seconds) seconds remaining"
                self.progressView.progress = Float(seconds) / 30.0
                if seconds > 20 {
                    self.progressView.progressTintColor = .systemGreen
                } else if seconds > 10 {
                    self.progressView.progressTintColor = .systemOrange
                } else {
                    self.progressView.progressTintColor = .systemRed
                }
            }
        }
        gameTimerManager.onFinished = { [weak self] in
            DispatchQueue.main.async {
                self?.stopListening()
                self?.timerLabel.text           = "Time over!"
                self?.progressView.progress     = 0
                self?.endRound()
            }
        }
        gameTimerManager.start()
    }

    func updateMicIcon() {
        micButton.setImage(
            UIImage(systemName: isRecording ? "stop.fill" : "mic.fill"),
            for: .normal
        )
    }

    // MARK: - Actions
    @IBAction func micButtonTapped(_ sender: UIButton) {
        if isRecording {
            stopListening()
        } else {
            resetTimer()
            didScoreCurrentWord = false
            startListening()
            startTimer()
        }
    }

    @IBAction func nextButtonTapped(_ sender: Any) {
        roundEnded        = false
        micButton.isEnabled = true
        localCorrectCount = 0
        localCurrentIndex = 0
        items.shuffle()
        resetTimer()
        loadWord()
        nextButton.isHidden = true
    }

    func startListening() {
        speechRecognitionManager.onWordDetected = { [weak self] spoken in
            guard let self,
                  !self.roundEnded,
                  self.items.indices.contains(self.localCurrentIndex),
                  !self.didScoreCurrentWord,
                  !spoken.isEmpty else { return }

            let expected = self.items[self.localCurrentIndex].speakableText.lowercased()

            if spoken.isPhoneticMatch(to: expected) {
                self.didScoreCurrentWord = true
                self.localCorrectCount  += 1
                self.localCurrentIndex  += 1

                self.phonicsGameplayManager.recordAttempt()
                self.phonicsGameplayManager.recordSuccess()

                DispatchQueue.main.async {
                    self.loadWord()
                    self.didScoreCurrentWord = false
                    self.restartRecognition()
                }
            }
        }
        speechRecognitionManager.startListening()
        isRecording = true
        updateMicIcon()
    }

    func restartRecognition() {
        speechRecognitionManager.stopListening()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.speechRecognitionManager.startListening()
        }
    }

    func stopListening() {
        speechRecognitionManager.stopListening()
        isRecording = false
        updateMicIcon()
    }

    // MARK: - Round End
    func endRound() {
        roundEnded          = true
        micButton.isEnabled = false
        gameTimerManager.stop()
        speechRecognitionManager.stopListening()

        scoreLabel.text      = "You pronounced \(localCorrectCount) words correctly!"
        scoreLabel.textColor = .systemGreen
        scoreLabel.isHidden  = false

        nextButton.setTitle("Next", for: .normal)
        nextButton.isHidden = false
    }

    // MARK: - Navigation
    @IBAction func backButtonTapped(_ sender: Any) {
        phonicsGameplayManager.endSession()
        goBackToPhonicsCover()
    }

    @IBAction func homeButtonTapped(_ sender: Any) {
        phonicsGameplayManager.endSession()
        phonicsGameplayManager.clearCycleProgress()
        goHomeFromPhonics()
    }
}
