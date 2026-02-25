//
//  RhymeWordsViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit
import AVFoundation

final class RhymeWordsViewController: UIViewController,
                                     ExerciseReceivesCover,
                                     ExerciseResumable {

    // MARK: - Outlets
    @IBOutlet private weak var feedbackLabel: UILabel!
    @IBOutlet private weak var submitButton: UIButton!
    @IBOutlet private weak var speakerButton: UIButton!

    @IBOutlet private weak var optionButton1: UIButton!
    @IBOutlet private weak var optionButton2: UIButton!
    @IBOutlet private weak var optionButton3: UIButton!
    @IBOutlet private weak var optionButton4: UIButton!
    @IBOutlet private weak var optionButton5: UIButton!
    @IBOutlet private weak var optionButton6: UIButton!

    // MARK: - Protocol Properties
    var exerciseType: ExerciseType?
    var startingIndex: Int?
    var coverWasShown: Bool = false
    
    var currentIndex: Int {
        return PhonicsGameplayManager.shared.getCurrentIndex()
    }

    // MARK: - Internal State
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var hasSpeakerBeenTapped = false
    
    private var questions: [RhymeQuestion] = []
    private var targetWord = ""
    private var options: [String] = []
    private var correctWords: [String] = []

    private var isAnswerLocked = false

    private lazy var optionButtons: [UIButton] = [
        optionButton1, optionButton2, optionButton3,
        optionButton4, optionButton5, optionButton6
    ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureGameData()
        configureUI()
        loadCurrentQuestion()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.startWigglingSpeakerButton()
        }
    }

    // MARK: - Configuration
    private func configureGameData() {
        self.questions = BundleDataLoader.shared.load("RhymeWordsQuestions", as: [RhymeQuestion].self)
        
        PhonicsGameplayManager.shared.startSession(
            for: .rhyme,
            totalQuestions: questions.count,
            startPointer: startingIndex ?? 0
        )
    }

    private func configureUI() {
        feedbackLabel.text = ""

        submitButton.configuration = nil
        submitButton.backgroundColor = UIColor(red: 117/255, green: 80/255, blue: 50/255, alpha: 1)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font = UIFont(name: "ArialRoundedMTBold", size: 35)
        submitButton.layer.cornerRadius = submitButton.bounds.height / 2

        speakerButton.layer.cornerRadius = speakerButton.bounds.height / 2

        optionButtons.forEach { applyUnselectedStyle($0) }
    }

    // MARK: - Question Flow
    private func loadCurrentQuestion() {
        let index = PhonicsGameplayManager.shared.getCurrentIndex()
        guard questions.indices.contains(index) else { return }
        
        let question = questions[index]
        loadQuestion(question)
    }

    private func loadQuestion(_ question: RhymeQuestion) {
        targetWord = question.targetWord
        correctWords = question.correctWords
        options = question.options.shuffled()

        isAnswerLocked = false
        feedbackLabel.text = ""
        submitButton.setTitle("Submit", for: .normal)

        for (index, button) in optionButtons.enumerated() {
            guard index < options.count else {
                button.isHidden = true
                continue
            }

            button.isHidden = false
            button.isSelected = false
            button.isUserInteractionEnabled = true
            button.setTitle(options[index], for: .normal)
            applyUnselectedStyle(button)
        }
    }

    private func moveToNextQuestion() {
        removeSticker()
        PhonicsGameplayManager.shared.advanceToNext()
        loadCurrentQuestion()
    }

    // MARK: - Actions
    @IBAction private func optionTapped(_ sender: UIButton) {
        sender.isSelected.toggle()
        sender.isSelected ? applySelectedStyle(sender) : applyUnselectedStyle(sender)
    }

    @IBAction private func speakerTapped(_ sender: UIButton) {
        hasSpeakerBeenTapped = true
        speakerButton.layer.removeAnimation(forKey: "speakerWiggle")
        let utterance = AVSpeechUtterance(string: targetWord)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = 0.35
        speechSynthesizer.speak(utterance)
    }

    @IBAction private func submitTapped(_ sender: UIButton) {
        if isAnswerLocked {
            moveToNextQuestion()
            return
        }

        PhonicsGameplayManager.shared.recordAttempt()

        let selected = Set(
            optionButtons
                .filter { $0.isSelected }
                .compactMap { $0.title(for: .normal) }
        )

        let correctSet = Set(correctWords)

        guard selected.isSubset(of: correctSet) else {
            showFeedback("Try again!", color: .systemRed)
            return
        }

        guard selected.count == correctSet.count else {
            let remaining = correctSet.count - selected.count
            showFeedback(
                remaining == 1 ? "One more word is correct"
                               : "\(remaining) more words are correct",
                color: .systemOrange
            )
            return
        }

        // Success!
        PhonicsGameplayManager.shared.recordSuccess()
        
        isAnswerLocked = true
        submitButton.setTitle("Next", for: .normal)
        optionButtons.forEach { $0.isUserInteractionEnabled = false }
        showFeedback("Correct!", color: .systemGreen)
        showStickerAtTopRight(assetName: "YouDidIt", horizontalOffset: 15)
    }

    private func showFeedback(_ text: String, color: UIColor) {
        feedbackLabel.text = text
        feedbackLabel.textColor = color
    }

    // MARK: - Navigation & Session
    @IBAction private func homeButtonTapped(_ sender: Any) {
        PhonicsGameplayManager.shared.endSession()
        PhonicsGameplayManager.shared.clearCycleProgress()
        goHomeFromPhonics()
    }

    @IBAction private func backButtonTapped(_ sender: Any) {
        PhonicsGameplayManager.shared.endSession()
        PhonicsGameplayManager.shared.clearCycleProgress()
        
        if let coverVC = navigationController?.viewControllers
            .compactMap({ $0 as? PhonicsCoverViewController })
            .last {
            coverVC.resumeCyclePointer = PhonicsGameplayManager.shared.getCyclePointer()
        }
        goBackToPhonicsCover()
    }

    // MARK: - Styling Helpers
    private func startWigglingSpeakerButton() {
        guard !hasSpeakerBeenTapped else { return }

        let wiggle = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        wiggle.values = [-0.12, 0.12, -0.08, 0.08, 0]
        wiggle.duration = 0.6
        wiggle.repeatCount = .infinity
        wiggle.isAdditive = true
        wiggle.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        speakerButton.layer.add(wiggle, forKey: "speakerWiggle")
    }

    private func applySelectedStyle(_ button: UIButton) {
        button.backgroundColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1)
        button.setTitleColor(.white, for: .normal)
        button.layer.borderWidth = 0
    }

    private func applyUnselectedStyle(_ button: UIButton) {
        button.configuration = nil

        button.backgroundColor = UIColor(red: 1, green: 0.976, blue: 0.839, alpha: 1)
        button.setTitleColor(UIColor(red: 0.42, green: 0.29, blue: 0.17, alpha: 1), for: .normal)

        button.titleLabel?.font = .systemFont(ofSize: 28, weight: .semibold)
        button.titleLabel?.isUserInteractionEnabled = false
        button.isPointerInteractionEnabled = false
        button.tintColor = .clear

        button.layer.cornerRadius = button.bounds.height / 2
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1).cgColor
        button.clipsToBounds = true
    }
}
