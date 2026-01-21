//
//  QuizMyStory-ViewController.swift
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit
import AVFoundation

final class QuizMyStory_ViewController: UIViewController,
                                       ExerciseReceivesCover,
                                       ExerciseResumable,
                                       ExerciseProgressReporting {

    // MARK: - Protocol State (DO NOT REMOVE)
    var exerciseType: ExerciseType?
    var startingIndex: Int?
    var coverWasShown: Bool = false
    private(set) var currentIndex = 0

    // MARK: - Session & Cycle
    private var phonicsSession: PhonicsSessionData?
    private var questionCycle: RandomizedQuestionCycle!
    private var hasSavedSession = false

    // MARK: - Internal State
    private var questions: [QuizQuestion] = []
    private var shuffledOptions: [(text: String, originalIndex: Int)] = []
    private var selectedOptionIndex: Int?
    private var isAnswerLocked = false

    private let speechSynth = AVSpeechSynthesizer()

    // MARK: - Outlets (ALL KEPT)
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
        configureSession()
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
    private func configureSession() {
        questions = QuizQuestionLoader.loadQuestions()

        if questions.isEmpty {
            print("Using fallback question because JSON failed.")
            questions = [
                QuizQuestion(
                    sentence: "Fallback story.",
                    question: "Fallback question?",
                    options: ["A", "B"],
                    correctIndex: 0
                )
            ]
        }

        phonicsSession = PhonicsSessionData(
            id: UUID(),
            date: Date(),
            childId: "default_child",
            exerciseType: "quiz_my_story",
            correctCount: 0,
            totalAttempts: 0,
            startTime: Date(),
            endTime: nil
        )

        questionCycle = ExerciseCycleStore.load(key: "quiz_my_story_cycle")
            ?? RandomizedQuestionCycle(
                count: questions.count,
                startPointer: startingIndex ?? 0
            )

        currentIndex = questionCycle.currentIndex()
    }

    private func configureUI() {
        titleLabel.text = "Quiz My Story"
        feedbackLabel.text = ""

        submitButton.configuration = nil
        submitButton.backgroundColor =
            UIColor(red: 117/255, green: 80/255, blue: 50/255, alpha: 1)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font =
            UIFont(name: "ArialRoundedMTBold", size: 35)
        submitButton.setTitle("Submit", for: .normal)

        yellowCardView.backgroundColor =
            UIColor(red: 1, green: 0.97, blue: 0.85, alpha: 1)
        yellowCardView.layer.borderWidth = 4
        yellowCardView.layer.borderColor =
            UIColor(red: 0.96, green: 0.92, blue: 0.66, alpha: 1).cgColor
        yellowCardView.clipsToBounds = true

        promptLabel.layer.borderWidth = 4
        promptLabel.layer.borderColor =
            UIColor(red: 0.96, green: 0.92, blue: 0.66, alpha: 1).cgColor
        promptLabel.clipsToBounds = true

        speakerButton.layer.borderWidth = 2
        speakerButton.layer.borderColor =
            UIColor(red: 0.88, green: 0.76, blue: 0.37, alpha: 1).cgColor
        speakerButton.clipsToBounds = true

        optionButtons.forEach(styleOptionButton)
    }

    // MARK: - Styling Helpers
    private func styleOptionButton(_ button: UIButton) {
        button.configuration = nil
        button.backgroundColor =
            UIColor(red: 1, green: 0.976, blue: 0.839, alpha: 1)
        button.setTitleColor(.brown, for: .normal)
        button.titleLabel?.font =
            .systemFont(ofSize: 28, weight: .semibold)
        button.layer.borderWidth = 3
        button.layer.borderColor =
            UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1).cgColor
        button.clipsToBounds = true
    }

    private func applySelectedStyle(_ button: UIButton) {
        button.backgroundColor =
            UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1)
        button.setTitleColor(.white, for: .normal)
        button.layer.borderWidth = 0
    }

    // MARK: - Question Flow
    private func loadCurrentQuestion() {
        guard questions.indices.contains(currentIndex) else { return }
        let question = questions[currentIndex]

        storyLabel.text = question.sentence
        promptLabel.text = question.question
        feedbackLabel.text = ""
        selectedOptionIndex = nil
        isAnswerLocked = false
        submitButton.setTitle("Submit", for: .normal)

        shuffledOptions = question.options.enumerated().map {
            (text: $0.element, originalIndex: $0.offset)
        }.shuffled()

        for (index, button) in optionButtons.enumerated() {
            button.isUserInteractionEnabled = true
            styleOptionButton(button)

            if index < shuffledOptions.count {
                button.isHidden = false
                button.setTitle(shuffledOptions[index].text, for: .normal)
                button.tag = index
            } else {
                button.isHidden = true
            }
        }
    }

    private func moveToNextQuestion() {
        questionCycle.moveToNext()
        currentIndex = questionCycle.currentIndex()
        ExerciseCycleStore.save(questionCycle, key: "quiz_my_story_cycle")
        loadCurrentQuestion()
    }

    // MARK: - Actions
    @IBAction func speakerTapped(_ sender: UIButton) {
        let text = questions[currentIndex].sentence
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

        phonicsSession?.totalAttempts += 1

        let correctIndex = questions[currentIndex].correctIndex
        let correctButtonIndex =
            shuffledOptions.firstIndex { $0.originalIndex == correctIndex }!

        if selected == correctButtonIndex {
            phonicsSession?.correctCount += 1
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

    // MARK: - Session & Navigation
    private func endSession() {
        guard let session = phonicsSession, !hasSavedSession else { return }
        AnalyticsStore.shared.appendPhonicsSession(session)
        hasSavedSession = true
    }

    @IBAction func backButtonTapped(_ sender: Any) {
        endSession()
        ExerciseCycleStore.clear(key: "quiz_my_story_cycle")

        if let coverVC = navigationController?.viewControllers
            .compactMap({ $0 as? PhonicsCoverViewController })
            .last {
            coverVC.resumeCyclePointer = questionCycle.pointer
        }

        goBackToPhonicsCover()
    }

    @IBAction func homeButtonTapped(_ sender: Any) {
        endSession()
        ExerciseCycleStore.clear(key: "quiz_my_story_cycle")
        goHomeFromPhonics()
    }
}
