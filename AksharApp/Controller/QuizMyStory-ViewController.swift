//
//  QuizMyStory-ViewController.swift
//  Screendesigns
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit
import AVFoundation

class QuizMyStory_ViewController: UIViewController, ExerciseReceivesCover, ExerciseResumable, ExerciseProgressReporting {
    
    // MARK: - Protocol State
    var exerciseType: ExerciseType?
    var startingIndex: Int? = nil
    var coverWasShown: Bool = false
    private(set) var currentIndex = 0
    
    // MARK: - Internal State
    private var shuffledOptions: [(text: String, originalIndex: Int)] = []
    private var didStyleUI = false
    private var questions: [QuizQuestion] = []
    private var selectedOptionIndex: Int? = nil
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
        questions = QuizQuestionLoader.loadQuestions()
        if questions.isEmpty {
                print("⚠️ Using fallback question because JSON failed.")
                questions = [
                    QuizQuestion(sentence: "Fallback story.",
                                 question: "Fallback question?",
                                 options: ["A", "B"],
                                 correctIndex: 0)
                ]
            }
        currentIndex = startingIndex ?? 0

        loadQuestion(at: currentIndex)
        submitButton.setTitle("Submit", for: .normal)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didStyleUI {
            styleUI()
            styleSubmitButton()
            didStyleUI = true
        }
    }
    
    // MARK: - Styling
    func styleUI() {
        yellowCardView.backgroundColor = UIColor(red: 1.0, green: 0.97, blue: 0.85, alpha: 1.0)
        yellowCardView.layer.cornerRadius = 20
        yellowCardView.layer.masksToBounds = true
        yellowCardView.layer.borderColor = UIColor(red: 0.96, green: 0.92, blue: 0.66, alpha: 1).cgColor
        yellowCardView.layer.borderWidth = 4
        promptLabel.layer.borderColor = UIColor(red: 0.96, green: 0.92, blue: 0.66, alpha: 1).cgColor
        promptLabel.layer.borderWidth = 4
        promptLabel.layer.cornerRadius = 20
        promptLabel.clipsToBounds = true
        speakerButton.layer.cornerRadius = speakerButton.bounds.height / 2
        speakerButton.layer.borderWidth = 2
        speakerButton.layer.borderColor = UIColor(red: 0.88, green: 0.76, blue: 0.37, alpha: 1).cgColor
        speakerButton.clipsToBounds = true
        for b in optionButtons {
            styleOptionButton(b)
        }
    }
    func styleSubmitButton() {
        submitButton.configuration = nil
        submitButton.backgroundColor = UIColor(red: 117/255,green: 80/255,blue: 50/255,alpha: 1.0)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font = UIFont(name: "ArialRoundedMTBold", size: 35)
        
        submitButton.layer.cornerRadius = submitButton.bounds.height/2
        submitButton.clipsToBounds = true
        feedbackLabel.isHidden = false
    }
    func styleOptionButton(_ button: UIButton) {
        button.configuration = nil
        button.backgroundColor = UIColor(red: 1.0, green: 0.976, blue: 0.839, alpha: 1)
        button.setTitleColor(UIColor.brown, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .semibold)
        button.layer.cornerRadius = button.bounds.height/2
        button.layer.borderWidth = 3
        button.layer.borderColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1).cgColor
        button.clipsToBounds = true
    }
    
    // MARK: - Question Loading
    func loadQuestion(at index: Int) {
        guard questions.indices.contains(index) else { return }
        let q = questions[index]
        storyLabel.text = q.sentence
        titleLabel.text = "Quiz My Story"
        promptLabel.text = q.question
        feedbackLabel.isHidden = false
        feedbackLabel.text = ""
        for btn in optionButtons {
            btn.isUserInteractionEnabled = true
            styleOptionButton(btn)
        }
        var paired = q.options.enumerated().map { (offset, element) in
            return (text: element, originalIndex: offset)
        }
        paired.shuffle()
        shuffledOptions = paired
        for (i, btn) in optionButtons.enumerated() {
            if i < shuffledOptions.count {
                btn.isHidden = false
                btn.setTitle(shuffledOptions[i].text, for: .normal)
                btn.tag = i
                styleOptionButton(btn)
            } else {
                btn.isHidden = true
            }
        }
        selectedOptionIndex = nil
    }
    func goToNextQuestion() {
        currentIndex += 1
        if currentIndex >= questions.count { currentIndex = 0 }
        loadQuestion(at: currentIndex)
    }
    
    // MARK: - Actions
    @IBAction func speakerTapped(_ sender: UIButton) {
        let q = questions[currentIndex]
        let speakText = q.sentence          // <-- SPEAK THE STORY, not the image name
        let utter = AVSpeechUtterance(string: speakText)
        utter.voice = AVSpeechSynthesisVoice(language: "en-US")
        utter.rate = 0.45
        speechSynth.speak(utter)
    }
    
    @IBAction func optionsTapped(_ sender: UIButton) {
        let tappedIndex = sender.tag

                if selectedOptionIndex == tappedIndex {
                    selectedOptionIndex = nil
                    styleOptionButton(sender)
                    return
                }
                for btn in optionButtons { styleOptionButton(btn) }
                selectedOptionIndex = tappedIndex
                sender.backgroundColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1)
                sender.setTitleColor(.white, for: .normal)
                sender.layer.borderWidth = 0
    }
    
    @IBAction func submitTapped(_ sender: UIButton) {
        if isAnswerLocked {
            isAnswerLocked = false
            submitButton.setTitle("Submit", for: .normal)
            styleSubmitButton()
            feedbackLabel.text = ""
            goToNextQuestion()
            return
        }
        guard let selected = selectedOptionIndex else {
            feedbackLabel.text = "Choose an option!"
            feedbackLabel.textColor = .systemOrange
            return
        }
        let correctIndex = questions[currentIndex].correctIndex
        let correctButtonIndex =
            shuffledOptions.firstIndex(where: { $0.originalIndex == correctIndex })!

        if selected == correctButtonIndex {
            feedbackLabel.text = "Correct!"
            feedbackLabel.textColor = .systemGreen
            isAnswerLocked = true
            submitButton.setTitle("Next", for: .normal)
            styleSubmitButton()
            for btn in optionButtons { btn.isUserInteractionEnabled = false }
        }

        else {
            feedbackLabel.text = "Try again!"
            feedbackLabel.textColor = .systemRed
        }
    }

    // MARK: - Navigation
    @IBAction func backButtonTapped(_ sender: Any) {
        if let coverVC = navigationController?.viewControllers
            .compactMap({ $0 as? PhonicsCoverViewController })
            .last {

            coverVC.resumeQuestionIndex = currentIndex
        }

        goBackToPhonicsCover()
    }
    @IBAction func homeButtonTapped(_ sender: Any) {
        goHomeFromPhonics()
    }
}
