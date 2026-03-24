import UIKit

final class QuizMyStory_ViewController: UIViewController,
                                       ExerciseDependencyReceivable, ExerciseReceivesCover,
                                        ExerciseSpeechReceivable, ExerciseResumable {

    var phonicsGameplayManager: PhonicsGameplayManager!
    var bundleDataLoader: BundleDataLoader!
    var speechManager: SpeechManager!

    var exerciseType: ExerciseType?
    var startingIndex: Int?
    var coverWasShown: Bool = false
    
    var currentIndex: Int {
        return phonicsGameplayManager.getCurrentIndex()
    }

    // MARK: - Internal State
    private var questions: [QuizQuestion] = []
    private var shuffledOptions: [(text: String, originalIndex: Int)] = []
    private var selectedOptionIndex: Int?
    private var isAnswerLocked = false

    // MARK: - Outlets
    @IBOutlet weak var feedbackLabel: UILabel!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var speakerButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var yellowCardView: UIView!
    @IBOutlet weak var storyLabel: UILabel!
    @IBOutlet weak var homeButton: UIButton!
    @IBOutlet var optionButtons: [UIButton]!
    @IBOutlet weak var promptLabel: UILabel!
    @IBOutlet var questionView: UIView!
    
    // MARK: - Lifecycle
    private func verifyDependencies() {
        assert(phonicsGameplayManager != nil, "phonicsGameplayManager was not injected into \(type(of: self))")
        assert(bundleDataLoader != nil, "bundleDataLoader was not injected into \(type(of: self))")
        assert(speechManager != nil, "speechManager was not injected into \(type(of: self))")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        verifyDependencies()
        speechManager.onSpeechFinished = { [weak self] in
            DispatchQueue.main.async {
                self?.speakerButton.setImage(
                    UIImage(systemName: "speaker.wave.2.fill"),
                    for: .normal
                )
            }
        }
        configureGameData()
        loadCurrentQuestion()
        configureUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        submitButton.layer.cornerRadius = submitButton.bounds.height / 2
        speakerButton.layer.cornerRadius = speakerButton.bounds.height / 2
        optionButtons.forEach { $0.layer.cornerRadius = $0.bounds.height / 2 }
        let cardRadius: CGFloat = 25
        yellowCardView.layer.cornerRadius = cardRadius
        questionView.layer.cornerRadius = cardRadius
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        speechManager.stop()
    }

    // MARK: - Initial Setup
    private func configureGameData() {
        self.questions = bundleDataLoader.load("QuizMyStoryQuestions", as: [QuizQuestion].self)

        if questions.isEmpty {
            questions = [
                QuizQuestion(
                    sentence: "Fallback story.",
                    question: "Fallback question?",
                    options: ["A", "B"],
                    correctIndex: 0
                )
            ]
        }

        phonicsGameplayManager.startSession(
            for: .quizMyStory,
            totalQuestions: questions.count,
            startPointer: startingIndex ?? 0
        )
    }

    private func configureUI() {
        titleLabel.text = "Quiz My Story"
        feedbackLabel.text = ""

        submitButton.configuration = nil
        submitButton.backgroundColor = UIColor(red: 117/255, green: 80/255, blue: 50/255, alpha: 1)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font = UIFont(name: "ArialRoundedMTBold", size: 35)
        submitButton.setTitle("Submit", for: .normal)

        yellowCardView.backgroundColor = UIColor(red: 1, green: 0.97, blue: 0.85, alpha: 1)
        yellowCardView.layer.borderWidth = 4
        yellowCardView.layer.borderColor = UIColor(red: 0.96, green: 0.92, blue: 0.66, alpha: 1).cgColor
        yellowCardView.clipsToBounds = true
        
        questionView.backgroundColor = UIColor(red: 1, green: 0.97, blue: 0.85, alpha: 1)
        questionView.layer.borderWidth = 4
        questionView.layer.borderColor = UIColor(red: 0.96, green: 0.92, blue: 0.66, alpha: 1).cgColor
        questionView.clipsToBounds = true

        speakerButton.layer.borderWidth = 2
        speakerButton.layer.borderColor = UIColor(red: 0.88, green: 0.76, blue: 0.37, alpha: 1).cgColor
        speakerButton.clipsToBounds = true

        optionButtons.forEach(styleOptionButton)
    }

    // MARK: - Styling Helpers
    private func styleOptionButton(_ button: UIButton) {
        button.configuration = nil
        button.backgroundColor = UIColor(red: 1, green: 0.976, blue: 0.839, alpha: 1)
        button.setTitleColor(.brown, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 28, weight: .semibold)
        button.layer.borderWidth = 3
        button.layer.borderColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1).cgColor
        button.clipsToBounds = true
    }

    private func applySelectedStyle(_ button: UIButton) {
        button.backgroundColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1)
        button.setTitleColor(.white, for: .normal)
        button.layer.borderWidth = 0
    }

    // MARK: - Question Flow
    private func loadCurrentQuestion() {
        speakerButton.setImage(
            UIImage(systemName: "speaker.wave.2.fill"),
            for: .normal
        )
        speakerButton.isEnabled = true
        let index = phonicsGameplayManager.getCurrentIndex()
        guard questions.indices.contains(index) else { return }
        
        let question = questions[index]

        storyLabel.text = question.sentence
        promptLabel.text = question.question
        feedbackLabel.text = ""
        selectedOptionIndex = nil
        isAnswerLocked = false
        submitButton.setTitle("Submit", for: .normal)

        shuffledOptions = question.options.enumerated().map {
            (text: $0.element, originalIndex: $0.offset)
        }.shuffled()

        for (i, button) in optionButtons.enumerated() {
            button.isUserInteractionEnabled = true
            styleOptionButton(button)

            if i < shuffledOptions.count {
                button.isHidden = false
                button.setTitle(shuffledOptions[i].text, for: .normal)
                button.tag = i
            } else {
                button.isHidden = true
            }
        }
    }

    private func moveToNextQuestion() {
        removeSticker()
        phonicsGameplayManager.advanceToNext()
        loadCurrentQuestion()
    }

    // MARK: - Actions
    @IBAction func speakerTapped(_ sender: UIButton) {

        if speechManager.isSpeaking() && !speechManager.isPaused() {
            speechManager.pause()
            sender.setImage(UIImage(systemName: "speaker.wave.2.fill"), for: .normal)
            return
        }

        if speechManager.isPaused() {
            speechManager.resume()
            sender.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            return
        }

        let index = phonicsGameplayManager.getCurrentIndex()
        guard questions.indices.contains(index) else { return }

        speechManager.speak(text: questions[index].sentence)

        sender.setImage(UIImage(systemName: "pause.fill"), for: .normal)
    }

    @IBAction func optionsTapped(_ sender: UIButton) {
        guard !isAnswerLocked else { return }
        feedbackLabel.text = ""
        let tappedIndex = sender.tag

        if selectedOptionIndex == tappedIndex {
            selectedOptionIndex = nil
            styleOptionButton(sender)
            return
        }

        optionButtons.forEach(styleOptionButton)
        selectedOptionIndex = tappedIndex
        applySelectedStyle(sender)
    }

    @IBAction func submitTapped(_ sender: UIButton) {
        speechManager.stop()
        speakerButton.setImage(UIImage(systemName: "speaker.wave.2.fill"), for: .normal)
        if isAnswerLocked {
            moveToNextQuestion()
            return
        }

        guard let selected = selectedOptionIndex else {
            feedbackLabel.text = "Choose an option!"
            feedbackLabel.textColor = .systemOrange
            return
        }
        
        phonicsGameplayManager.recordAttempt()
        
        let index = phonicsGameplayManager.getCurrentIndex()
        let correctIndex = questions[index].correctIndex
        
        guard let correctButtonIndex =
            shuffledOptions.firstIndex(where: { $0.originalIndex == correctIndex })
        else {
            return
        }

        if selected == correctButtonIndex {
            phonicsGameplayManager.recordSuccess()
            
            feedbackLabel.text = "Correct!"
            feedbackLabel.textColor = .systemGreen
            isAnswerLocked = true
            submitButton.setTitle("Next", for: .normal)
            optionButtons.forEach { $0.isUserInteractionEnabled = false }
            speakerButton.isEnabled = false
            showStickerAtTopRight(assetName: "YouDidIt", horizontalOffset: 5)
        } else {
            feedbackLabel.text = "Try again!"
            feedbackLabel.textColor = .systemRed
        }
    }

    // MARK: - Navigation
    @IBAction func backButtonTapped(_ sender: Any) {
        phonicsGameplayManager.endSession()
        phonicsGameplayManager.clearCycleProgress()

        if let coverVC = navigationController?.viewControllers
            .compactMap({ $0 as? PhonicsCoverViewController })
            .last {
            coverVC.resumeCyclePointer = phonicsGameplayManager.getCyclePointer()
        }

        goBackToPhonicsCover()
    }

    @IBAction func homeButtonTapped(_ sender: Any) {
        phonicsGameplayManager.endSession()
        phonicsGameplayManager.clearCycleProgress()
        goHomeFromPhonics()
    }
}
