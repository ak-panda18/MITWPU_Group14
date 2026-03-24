import UIKit

final class SoundDetectorViewController: UIViewController,
                                        ExerciseDependencyReceivable, ExerciseReceivesCover, ExerciseSpeechReceivable,
                                        ExerciseResumable {

    var phonicsGameplayManager: PhonicsGameplayManager!
    var bundleDataLoader: BundleDataLoader!

    var exerciseType: ExerciseType?
    var coverWasShown: Bool = false
    var startingIndex: Int?

    var currentIndex: Int {
        return phonicsGameplayManager.getCurrentIndex()
    }

    // MARK: - Internal State
    private var questions: [SoundQuestion] = []
    private var selectedInitial: String?
    private var isAnswerLocked = false

    var speechManager: SpeechManager!
    private var hasSoundButtonBeenTapped = false

    // MARK: - Outlets
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet private weak var submitButton: UIButton!
    @IBOutlet private weak var soundButton: UIButton!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var yellowView: UIView!
    @IBOutlet private weak var feedbackLabel: UILabel!

    @IBOutlet private weak var optionButton1: UIButton!
    @IBOutlet private weak var optionButton2: UIButton!
    @IBOutlet private weak var optionButton3: UIButton!
    @IBOutlet private weak var optionButton4: UIButton!

    // MARK: - Computed Collections
    private var optionButtons: [UIButton] {
        [optionButton1, optionButton2, optionButton3, optionButton4]
    }

    // MARK: - Lifecycle
    private func verifyDependencies() {
        assert(phonicsGameplayManager != nil, "phonicsGameplayManager was not injected into \(type(of: self))")
        assert(bundleDataLoader != nil, "bundleDataLoader was not injected into \(type(of: self))")
        assert(speechManager != nil, "speechManager was not injected into \(type(of: self))")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        verifyDependencies()
        configureGameData()
        configureUI()
        loadCurrentQuestion()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        submitButton.layer.cornerRadius = submitButton.bounds.height / 2
        soundButton.layer.cornerRadius = soundButton.bounds.height / 2
        optionButtons.forEach { $0.layer.cornerRadius = $0.bounds.height / 2 }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.startWigglingSoundButton()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        speechManager.stop()
    }

    // MARK: - Initial Setup
    private func configureGameData() {
        self.questions = bundleDataLoader.load("SoundQuestions", as: [SoundQuestion].self)
        
        guard !questions.isEmpty else {
            return
        }

        phonicsGameplayManager.startSession(
            for: .detective,
            totalQuestions: questions.count,
            startPointer: startingIndex ?? 0
        )
    }

    private func configureUI() {
        feedbackLabel.isHidden = true

        submitButton.configuration = nil
        submitButton.backgroundColor = UIColor(red: 117/255, green: 80/255, blue: 50/255, alpha: 1)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font = UIFont(name: "ArialRoundedMTBold", size: 35)
        
        yellowView.layer.cornerRadius = 20
        yellowView.layer.borderWidth = 4
        yellowView.layer.borderColor = UIColor(red: 0.96, green: 0.92, blue: 0.66, alpha: 1).cgColor
        yellowView.clipsToBounds = true

        soundButton.layer.borderWidth = 2
        soundButton.layer.borderColor = UIColor(red: 0.88, green: 0.76, blue: 0.37, alpha: 1).cgColor
        soundButton.clipsToBounds = true

        optionButtons.forEach(styleOptionButton)
    }

    // MARK: - Question Flow
    private func loadCurrentQuestion() {
        let index = phonicsGameplayManager.getCurrentIndex()
        guard questions.indices.contains(index) else { return }
        
        loadQuestion(questions[index])
    }

    private func loadQuestion(_ question: SoundQuestion) {
        soundButton.isEnabled = true 
        speechManager.stop()
        isAnswerLocked = false
        selectedInitial = nil
        feedbackLabel.isHidden = true
        submitButton.setTitle("Submit", for: .normal)
        
        submitButton.isEnabled = false
        submitButton.alpha = 0.5

        imageView.image = UIImage(named: question.imageName)

        for (index, button) in optionButtons.enumerated() {
            button.setTitle(question.options[index], for: .normal)
            button.isEnabled = false
            styleDisabledOptionButton(button)
        }
    }

    private func moveToNextQuestion() {
        removeSticker()
        phonicsGameplayManager.advanceToNext()
        loadCurrentQuestion()
    }
    
    private func stopSpeech() {
        speechManager.stop()
    }

    // MARK: - Actions
    @IBAction private func soundTapped(_ sender: UIButton) {
        hasSoundButtonBeenTapped = true
        stopWigglingSoundButton()

        optionButtons.forEach {
            $0.isEnabled = true
            styleOptionButton($0)
        }

        let index = phonicsGameplayManager.getCurrentIndex()
        guard questions.indices.contains(index) else { return }

        speechManager.speak(text: questions[index].word)
    }

    @IBAction private func optionTapped(_ sender: UIButton) {
        guard !isAnswerLocked else { return }
        let chosen = sender.title(for: .normal)

        if selectedInitial == chosen {
            selectedInitial = nil
            styleOptionButton(sender)

            submitButton.isEnabled = false
            submitButton.alpha = 0.5
            return
        }

        optionButtons.forEach(styleOptionButton)
        selectedInitial = chosen
        applySelectedStyle(sender)

        submitButton.isEnabled = true
        submitButton.alpha = 1.0
    }

    @IBAction private func submitTapped(_ sender: UIButton) {
        stopSpeech()
        if isAnswerLocked {
            moveToNextQuestion()
            return
        }
        
        phonicsGameplayManager.recordAttempt()

        guard let selected = selectedInitial else {
            showFeedback("Choose a letter", color: .systemOrange)
            return
        }
        
        let index = phonicsGameplayManager.getCurrentIndex()
        guard questions.indices.contains(index) else { return }
        let correct = questions[index].correctInitial.uppercased()

        if selected.uppercased() == correct {
            phonicsGameplayManager.recordSuccess()
            
            optionButtons.forEach { $0.isEnabled = false }
            isAnswerLocked = true
            submitButton.setTitle("Next", for: .normal)
            soundButton.isEnabled = false
            showFeedback("Correct!", color: .systemGreen)
            showStickerAtTopRight(assetName: "YouDidIt", horizontalOffset: 5)
        } else {
            showFeedback("Try again!", color: .systemRed)
        }
    }

    private func showFeedback(_ text: String, color: UIColor) {
        feedbackLabel.isHidden = false
        feedbackLabel.text = text
        feedbackLabel.textColor = color
    }

    // MARK: - Navigation
    @IBAction private func homeButtonTapped(_ sender: Any) {
        stopSpeech()
        phonicsGameplayManager.endSession()
        phonicsGameplayManager.clearCycleProgress()
        goHomeFromPhonics()
    }

    @IBAction private func backButtonTapped(_ sender: Any) {
        stopSpeech()
        phonicsGameplayManager.endSession()
        phonicsGameplayManager.clearCycleProgress()

        if let coverVC = navigationController?.viewControllers
            .compactMap({ $0 as? PhonicsCoverViewController })
            .last {
            coverVC.resumeCyclePointer = phonicsGameplayManager.getCyclePointer()
        }

        goBackToPhonicsCover()
    }

    // MARK: - Styling Helpers
    private func startWigglingSoundButton() {
        guard !hasSoundButtonBeenTapped else { return }
        let wiggle = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        wiggle.values = [-0.12, 0.12, -0.08, 0.08, 0]
        wiggle.duration = 0.6
        wiggle.repeatCount = .infinity
        wiggle.isAdditive = true
        wiggle.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        soundButton.layer.add(wiggle, forKey: "soundWiggle")
    }

    private func stopWigglingSoundButton() {
        soundButton.layer.removeAnimation(forKey: "soundWiggle")
    }
    
    private func styleDisabledOptionButton(_ button: UIButton) {
        button.configuration = nil
        button.backgroundColor = UIColor(red: 1, green: 0.976, blue: 0.839, alpha: 0.4)
        button.setTitleColor(.brown.withAlphaComponent(0.4), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 28, weight: .semibold)
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 0.3).cgColor
        button.clipsToBounds = true
    }

    private func styleOptionButton(_ button: UIButton) {
        button.configuration = nil
        button.backgroundColor = UIColor(red: 1, green: 0.976, blue: 0.839, alpha: 1)
        button.setTitleColor(.brown, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 28, weight: .semibold)
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1).cgColor
        button.clipsToBounds = true
    }

    private func applySelectedStyle(_ button: UIButton) {
        button.backgroundColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1)
        button.setTitleColor(.white, for: .normal)
        button.layer.borderWidth = 0
    }
}
