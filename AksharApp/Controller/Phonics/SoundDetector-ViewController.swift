//
//  SoundDetector-ViewController.swift
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit
import AVFoundation

final class SoundDetectorViewController: UIViewController,
                                        ExerciseReceivesCover,
                                        ExerciseResumable,
                                        ExerciseProgressReporting {
    // MARK: - Properties
    var exerciseType: ExerciseType?
    var coverWasShown: Bool = false
    var startingIndex: Int?
    private(set) var currentIndex = 0

    private var phonicsSession: PhonicsSessionData?
    private var questionCycle: RandomizedQuestionCycle!
    private var hasSavedSession = false

    private var questions: [SoundQuestion] = []
    private var selectedInitial: String?
    private var isAnswerLocked = false

    private let speechSynth = AVSpeechSynthesizer()
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
    override func viewDidLoad() {
        super.viewDidLoad()
        configureSession()
        configureUI()
        loadQuestion()
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

    // MARK: - Initial Setup
    private func configureSession() {
        questions = SoundQuestionLoader.loadQuestions()
        guard !questions.isEmpty else {
            print("No Sound Detector questions loaded")
            return
        }

        phonicsSession = PhonicsSessionData(
            id: UUID(),
            date: Date(),
            childId: "default_child",
            exerciseType: "sound_detector",
            correctCount: 0,
            totalAttempts: 0,
            startTime: Date(),
            endTime: nil
        )

        questionCycle = ExerciseCycleStore.load(key: "sound_detector_cycle")
            ?? RandomizedQuestionCycle(
                count: questions.count,
                startPointer: startingIndex ?? 0
            )

        currentIndex = questionCycle.currentIndex()
    }

    private func configureUI() {
        feedbackLabel.isHidden = true

        submitButton.configuration = nil
        submitButton.backgroundColor =
            UIColor(red: 117/255, green: 80/255, blue: 50/255, alpha: 1)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font =
            UIFont(name: "ArialRoundedMTBold", size: 35)

        yellowView.layer.borderWidth = 4
        yellowView.layer.borderColor =
            UIColor(red: 0.96, green: 0.92, blue: 0.66, alpha: 1).cgColor
        yellowView.clipsToBounds = true

        soundButton.layer.borderWidth = 2
        soundButton.layer.borderColor =
            UIColor(red: 0.88, green: 0.76, blue: 0.37, alpha: 1).cgColor
        soundButton.clipsToBounds = true

        optionButtons.forEach(styleOptionButton)
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

    private func styleOptionButton(_ button: UIButton) {
        button.configuration = nil
        button.backgroundColor =
            UIColor(red: 1, green: 0.976, blue: 0.839, alpha: 1)
        button.setTitleColor(.brown, for: .normal)
        button.titleLabel?.font =
            .systemFont(ofSize: 28, weight: .semibold)
        button.layer.borderWidth = 2
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
    private func loadQuestion() {
        isAnswerLocked = false
        selectedInitial = nil
        feedbackLabel.isHidden = true
        submitButton.setTitle("Submit", for: .normal)

        let question = questions[currentIndex]
        imageView.image = UIImage(named: question.imageName)

        for (index, button) in optionButtons.enumerated() {
            button.setTitle(question.options[index], for: .normal)
            button.isEnabled = true
            styleOptionButton(button)
        }
    }

    private func moveToNextQuestion() {
        questionCycle.moveToNext()
        currentIndex = questionCycle.currentIndex()
        ExerciseCycleStore.save(questionCycle, key: "sound_detector_cycle")
        loadQuestion()
    }

    // MARK: - Actions
    @IBAction private func soundTapped(_ sender: UIButton) {
        hasSoundButtonBeenTapped=true
        stopWigglingSoundButton()
        let word = questions[currentIndex].word
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = 0.35
        speechSynth.speak(utterance)
    }

    @IBAction private func optionTapped(_ sender: UIButton) {
        let chosen = sender.title(for: .normal)

        if selectedInitial == chosen {
            selectedInitial = nil
            styleOptionButton(sender)
            return
        }

        optionButtons.forEach(styleOptionButton)
        selectedInitial = chosen
        applySelectedStyle(sender)
    }

    @IBAction private func submitTapped(_ sender: UIButton) {
        if isAnswerLocked {
            moveToNextQuestion()
            return
        }

        phonicsSession?.totalAttempts += 1

        guard let selected = selectedInitial else {
            showFeedback("Choose a letter", color: .systemOrange)
            return
        }

        let correct = questions[currentIndex].correctInitial.uppercased()

        if selected.uppercased() == correct {
            phonicsSession?.correctCount += 1
            optionButtons.forEach { $0.isEnabled = false }
            isAnswerLocked = true
            submitButton.setTitle("Next", for: .normal)
            showFeedback("Correct!", color: .systemGreen)
            triggerConfetti()
        } else {
            showFeedback("Try again!", color: .systemRed)
        }
    }

    private func showFeedback(_ text: String, color: UIColor) {
        feedbackLabel.isHidden = false
        feedbackLabel.text = text
        feedbackLabel.textColor = color
    }

    // MARK: - Navigation & Session
    private func endSession() {
        guard var session = phonicsSession, !hasSavedSession else { return }
        session.endTime = Date()
        AnalyticsStore.shared.appendPhonicsSession(session)
        hasSavedSession = true
    }

    @IBAction private func homeButtonTapped(_ sender: Any) {
        endSession()
        ExerciseCycleStore.clear(key: "sound_detector_cycle")
        goHomeFromPhonics()
    }

    @IBAction private func backButtonTapped(_ sender: Any) {
        endSession()
        ExerciseCycleStore.clear(key: "sound_detector_cycle")

        if let coverVC = navigationController?.viewControllers
            .compactMap({ $0 as? PhonicsCoverViewController })
            .last {
            coverVC.resumeCyclePointer = questionCycle.pointer
        }

        goBackToPhonicsCover()
    }
}
