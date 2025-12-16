//
//  RhymeWords-ViewController.swift
//  Screendesigns
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit
import AVFoundation
 
class RhymeWords_ViewController: UIViewController, ExerciseReceivesCover, ExerciseResumable, ExerciseProgressReporting {
    
    // MARK: - Protocol State
    var exerciseType: ExerciseType?
    var startingIndex: Int? = nil
    var coverWasShown: Bool = false
    private(set) var currentQuestionIndex: Int = 0
    var currentIndex: Int { currentQuestionIndex }
    
    // MARK: - Internal State
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var questions: [RhymeQuestion] = []
    private var isAnswerLocked = false
    private var targetWord: String = ""
    private var options: [String] = []
    private var correctWords: [String] = []
    private var didStyleUI = false

    // MARK: - Outlets
    @IBOutlet weak var optionButton6: UIButton!
    @IBOutlet weak var optionButton5: UIButton!
    @IBOutlet weak var optionButton4: UIButton!
    @IBOutlet weak var optionButton3: UIButton!
    @IBOutlet weak var optionButton2: UIButton!
    @IBOutlet weak var optionButton1: UIButton!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var speakerButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var homeButton: UIButton!
    @IBOutlet weak var feedbackLabel: UILabel!

    // MARK: - Computed UI Collections
    private lazy var optionButtons: [UIButton] = [
            optionButton1, optionButton2, optionButton3,
            optionButton4, optionButton5, optionButton6]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        feedbackLabel.text = ""

        questions = RhymeQuestionLoader.loadQuestions()
        submitButton.setTitle("Submit", for: .normal)
        currentQuestionIndex = startingIndex ?? 0

        if questions.isEmpty {
            print("⚠️ No questions loaded from JSON")
        } else {
            loadQuestion(questions[currentQuestionIndex])
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didStyleUI {
            styleSubmitAndSpeaker()
            styleOptionButtonsFully()
            didStyleUI = true
        }
    }
    
    // MARK: - Styling
    func styleOptionButtonsFully() {
        for btn in optionButtons {
            btn.configuration = nil
            btn.tintColor = .clear
            btn.showsMenuAsPrimaryAction = false
            
            btn.backgroundColor = UIColor(red: 1.0, green: 0.976, blue: 0.839, alpha: 1)
            btn.setTitleColor(UIColor(red: 0.42, green: 0.29, blue: 0.17, alpha: 1), for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .semibold)
            
            btn.layer.cornerRadius = btn.bounds.height / 2
            btn.layer.borderWidth = 2
            btn.layer.borderColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1).cgColor
            btn.clipsToBounds = true
        }
    }
    
    func applySelectedStyle(_ btn: UIButton) {
         btn.backgroundColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1)
         btn.setTitleColor(.white, for: .normal)
         btn.layer.borderWidth = 0
     }
    
    func applyUnselectedStyle(_ btn: UIButton) {
        btn.backgroundColor = UIColor(red: 1.0, green: 0.976, blue: 0.839, alpha: 1)
        btn.setTitleColor(UIColor(red: 0.42, green: 0.29, blue: 0.17, alpha: 1), for: .normal)
        btn.layer.borderWidth = 2
        btn.layer.borderColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1).cgColor
    }
    
    func styleSubmitAndSpeaker() {
        submitButton.configuration = nil
        submitButton.backgroundColor = UIColor(red: 117/255,green: 80/255,blue: 50/255,alpha: 1.0)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font = UIFont(name: "ArialRoundedMTBold", size: 35)
        submitButton.layer.cornerRadius = submitButton.bounds.height / 2
        submitButton.clipsToBounds = true
        speakerButton.layer.cornerRadius = speakerButton.bounds.height / 2
        speakerButton.clipsToBounds = true
    }
    
    // MARK: - Question Loading
    func loadQuestion(_ q: RhymeQuestion) {
        targetWord = q.targetWord
        correctWords = q.correctWords
        options = q.options.shuffled()
        isAnswerLocked = false
        feedbackLabel.text = ""
        for (i, btn) in optionButtons.enumerated() {
            guard i < options.count else {
                btn.isHidden = true
                continue
            }
            btn.isHidden = false
            btn.isSelected = false
            btn.isUserInteractionEnabled = true
            btn.setTitle(options[i], for: .normal)
            applyUnselectedStyle(btn)
        }
    }

    // MARK: - Actions
    @IBAction func optionTapped(_ sender: UIButton) {
        sender.isSelected.toggle()
        
        if sender.isSelected {
            applySelectedStyle(sender)
        } else {
            applyUnselectedStyle(sender)
        }
    }
    
    @IBAction func speakerTapped(_ sender: UIButton) {
        let utterance = AVSpeechUtterance(string: targetWord)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        speechSynthesizer.speak(utterance)
    }
    
     @IBAction func submitTapped(_ sender: UIButton) {
         if isAnswerLocked {
             loadNextQuestion()
             return
         }

         let selected = optionButtons
             .filter { $0.isSelected }
             .compactMap { $0.title(for: .normal) }

         if Set(selected) == Set(correctWords) {
             feedbackLabel.text = "Correct!"
             feedbackLabel.textColor = .systemGreen
             isAnswerLocked = true
             submitButton.setTitle("Next", for: .normal)
             optionButtons.forEach { $0.isUserInteractionEnabled = false }
         }

         else {
             feedbackLabel.text = "Incorrect!"
             feedbackLabel.textColor = .systemRed
         }
     }
    func loadNextQuestion() {
        feedbackLabel.text = ""
        isAnswerLocked = false
        submitButton.setTitle("Submit", for: .normal)

        currentQuestionIndex += 1
        if currentQuestionIndex >= questions.count {
            currentQuestionIndex = 0
        }

        loadQuestion(questions[currentQuestionIndex])
    }
    @IBAction func homeButtonTapped(_ sender: Any) {
        goHomeFromPhonics()
    }
    @IBAction func backButtonTapped(_ sender: Any) {
        if let coverVC = navigationController?.viewControllers
            .compactMap({ $0 as? PhonicsCoverViewController })
            .last {

            coverVC.resumeQuestionIndex = currentQuestionIndex
        }

        goBackToPhonicsCover()
    }
}
  


