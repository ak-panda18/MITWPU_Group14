//
//  QuizMyStory-ViewController.swift
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit
import AVFoundation

final class QuizMyStory_ViewController: UIViewController,
                                       ExerciseReceivesCover,
                                       ExerciseResumable {

    // MARK: - Protocol State
    var exerciseType: ExerciseType?
    var startingIndex: Int?
    var coverWasShown: Bool = false
    
    // We get the index from the Manager
    var currentIndex: Int {
        return PhonicsGameplayManager.shared.getCurrentIndex()
    }

    // MARK: - Internal State
    private var questions: [QuizQuestion] = []
    private var shuffledOptions: [(text: String, originalIndex: Int)] = []
    private var selectedOptionIndex: Int?
    private var isAnswerLocked = false

    private let speechSynth = AVSpeechSynthesizer()

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

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureGameData()
        configureUI()
        loadCurrentQuestion()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        submitButton.layer.cornerRadius = submitButton.bounds.height / 2
        speakerButton.layer.cornerRadius = speakerButton.bounds.height / 2
        optionButtons.forEach { $0.layer.cornerRadius = $0.bounds.height / 2 }
    }

    // MARK: - Initial Setup
    private func configureGameData() {
        // 1. Load Data
        questions = QuizQuestionLoader.loadQuestions()

        if questions.isEmpty {
            // Fallback if load fails
            questions = [
                QuizQuestion(
                    sentence: "Fallback story.",
                    question: "Fallback question?",
                    options: ["A", "B"],
                    correctIndex: 0
                )
            ]
        }

        // 2. Start Manager Session
        PhonicsGameplayManager.shared.startSession(
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

        promptLabel.layer.borderWidth = 4
        promptLabel.layer.borderColor = UIColor(red: 0.96, green: 0.92, blue: 0.66, alpha: 1).cgColor
        promptLabel.clipsToBounds = true

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
        let index = PhonicsGameplayManager.shared.getCurrentIndex()
        guard questions.indices.contains(index) else { return }
        
        let question = questions[index]

        storyLabel.text = question.sentence
        promptLabel.text = question.question
        feedbackLabel.text = ""
        selectedOptionIndex = nil
        isAnswerLocked = false
        submitButton.setTitle("Submit", for: .normal)

        // Shuffle options and keep track of original index to verify answer later
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
        PhonicsGameplayManager.shared.advanceToNext()
        loadCurrentQuestion()
    }

    // MARK: - Actions
    @IBAction func speakerTapped(_ sender: UIButton) {
        let index = PhonicsGameplayManager.shared.getCurrentIndex()
        guard questions.indices.contains(index) else { return }
        
        let text = questions[index].sentence
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = 0.35
        speechSynth.speak(utterance)
    }

    @IBAction func optionsTapped(_ sender: UIButton) {
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
        if isAnswerLocked {
            moveToNextQuestion()
            return
        }

        guard let selected = selectedOptionIndex else {
            feedbackLabel.text = "Choose an option!"
            feedbackLabel.textColor = .systemOrange
            return
        }
        
        // 1. Record Attempt
        PhonicsGameplayManager.shared.recordAttempt()
        
        let index = PhonicsGameplayManager.shared.getCurrentIndex()
        let correctIndex = questions[index].correctIndex
        
        // Find which button corresponds to the correct original index
        let correctButtonIndex = shuffledOptions.firstIndex { $0.originalIndex == correctIndex }!

        if selected == correctButtonIndex {
            // 2. Record Success
            PhonicsGameplayManager.shared.recordSuccess()
            
            feedbackLabel.text = "Correct!"
            feedbackLabel.textColor = .systemGreen
            isAnswerLocked = true
            submitButton.setTitle("Next", for: .normal)
            optionButtons.forEach { $0.isUserInteractionEnabled = false }
            triggerConfetti()
        } else {
            feedbackLabel.text = "Try again!"
            feedbackLabel.textColor = .systemRed
        }
    }

    // MARK: - Navigation
    @IBAction func backButtonTapped(_ sender: Any) {
        PhonicsGameplayManager.shared.endSession()
        PhonicsGameplayManager.shared.clearCycleProgress()

        if let coverVC = navigationController?.viewControllers
            .compactMap({ $0 as? PhonicsCoverViewController })
            .last {
            coverVC.resumeCyclePointer = PhonicsGameplayManager.shared.getCyclePointer()
        }

        goBackToPhonicsCover()
    }

    @IBAction func homeButtonTapped(_ sender: Any) {
        PhonicsGameplayManager.shared.endSession()
        PhonicsGameplayManager.shared.clearCycleProgress()
        goHomeFromPhonics()
    }
}
