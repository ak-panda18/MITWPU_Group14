//
//  SoundDetector-ViewController.swift
//  Screendesigns
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit
import AVFoundation

class SoundDetector_ViewController: UIViewController, ExerciseReceivesCover, ExerciseResumable, ExerciseProgressReporting  {
    
    // MARK: - Protocol State
    var exerciseType: ExerciseType?
    var coverWasShown: Bool = false
    var startingIndex: Int? = nil
    private(set) var currentIndex = 0
    
    // MARK: - Internal State
    private var questions: [SoundQuestion] = []
    private var isAnswerLocked = false
    private var selectedInitial: String? = nil
    private var didStyleUI = false
    private let speechSynth = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?

    // MARK: - Outlets
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var optionButton4: UIButton!
    @IBOutlet weak var optionButton3: UIButton!
    @IBOutlet weak var optionButton2: UIButton!
    @IBOutlet weak var optionButton1: UIButton!
    @IBOutlet weak var soundButton: UIButton!
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var yellowView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var homeButton: UIButton!
    @IBOutlet weak var feedbackLabel: UILabel!
    
    // MARK: - Computed UI Collections
    private var optionButtons: [UIButton] {
        [optionButton1, optionButton2, optionButton3, optionButton4]
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        questions = SoundQuestionLoader.loadQuestions()
        if questions.isEmpty {
            print("⚠️ No Sound Detective questions loaded")
            return
        }
        currentIndex = startingIndex ?? 0
        yellowView.layer.cornerRadius = 20
        yellowView.layer.borderColor = UIColor(red: 0.96, green: 0.92, blue: 0.66, alpha: 1).cgColor
        yellowView.layer.borderWidth = 4
        soundButton.layer.borderColor = UIColor(red: 0.88, green: 0.76, blue: 0.37, alpha: 1).cgColor
        soundButton.layer.borderWidth = 2
        loadQuestion()
        feedbackLabel.isHidden = true
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didStyleUI {
            styleSubmitButton()
            styleSoundButton()
            styleYellowView()
            didStyleUI = true
        }
    }

    // MARK: - Styling
    func styleYellowView() {
        yellowView.layer.cornerRadius = 20
        yellowView.layer.borderColor = UIColor(red: 0.96, green: 0.92, blue: 0.66, alpha: 1).cgColor
        yellowView.layer.borderWidth = 4
        yellowView.clipsToBounds = true
    }

    func styleSoundButton() {
        soundButton.layer.cornerRadius = soundButton.bounds.height / 2
        soundButton.layer.borderColor = UIColor(red: 0.88, green: 0.76, blue: 0.37, alpha: 1).cgColor
        soundButton.layer.borderWidth = 2
        soundButton.clipsToBounds = true
    }
    func styleSubmitButton() {
        submitButton.configuration = nil
        submitButton.backgroundColor = UIColor(red: 117/255,green: 80/255,blue: 50/255,alpha: 1.0)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font = UIFont(name: "ArialRoundedMTBold", size: 35)
        submitButton.layer.cornerRadius = submitButton.bounds.height/2
        submitButton.clipsToBounds = true
    }
    func styleOptionButton(_ button: UIButton) {
        button.configuration = nil
        button.backgroundColor = UIColor(red: 1.0, green: 0.976, blue: 0.839, alpha: 1)
        button.setTitleColor(.brown, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .semibold)
        button.layer.cornerRadius = button.bounds.height / 2
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1).cgColor
        button.clipsToBounds = true
    }
    
    // MARK: - Question Loading
    func loadQuestion() {
        isAnswerLocked = false
        feedbackLabel.isHidden = true
        selectedInitial = nil
        let q = questions[currentIndex]
        image.image = UIImage(named: q.imageName)
        for (i, btn) in optionButtons.enumerated() {
            btn.setTitle(q.options[i], for: .normal)
            btn.isHidden = false
            styleOptionButton(btn)

            btn.isEnabled = true
        }
        selectedInitial = nil
        feedbackLabel.isHidden = true
        submitButton.setTitle("Submit", for: .normal)
        styleSubmitButton()
    }
    func goToNextQuestion() {
        currentIndex += 1
        if currentIndex >= questions.count { currentIndex = 0 }
        loadQuestion()
    }
    
    // MARK: - Actions
    @IBAction func soundTapped(_ sender: UIButton) {
        let q = questions[currentIndex]
        let utter = AVSpeechUtterance(string: q.word)
        utter.voice = AVSpeechSynthesisVoice(language: "en-US")
        utter.rate = 0.45
        speechSynth.speak(utter)
    }
    
    @IBAction func optionTapped(_ sender: UIButton) {
        let chosen = sender.title(for: .normal)
        
        if selectedInitial == chosen {
            selectedInitial = nil
           styleOptionButton(sender)
            return
        }
        for btn in optionButtons { styleOptionButton(btn) }
        
        selectedInitial = chosen
        sender.backgroundColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1)
        sender.setTitleColor(.white, for: .normal)
        sender.layer.borderWidth = 0
    }
    @IBAction func submitTapped(_ sender: UIButton) {
        if isAnswerLocked {
            isAnswerLocked = false
            goToNextQuestion()
            return
        }

        guard let selected = selectedInitial else {
            feedbackLabel.isHidden = false
            feedbackLabel.text = "Choose a letter"
            feedbackLabel.textColor = UIColor.systemOrange
            return
        }

        let correct = questions[currentIndex].correctInitial.uppercased()

        if selected.uppercased() == correct {
            feedbackLabel.isHidden = false
            feedbackLabel.text = "Correct!"
            feedbackLabel.textColor = UIColor.systemGreen
            for btn in optionButtons {
                btn.isEnabled = false
            }
            isAnswerLocked = true
            submitButton.setTitle("Next", for: .normal)
            styleSubmitButton()

        } else {
            feedbackLabel.isHidden = false
            feedbackLabel.text = "Try again!"
            feedbackLabel.textColor = UIColor.systemRed
        }
    }
    @IBAction func homeButtonTapped(_ sender: Any) {
        goHomeFromPhonics()
    }
    @IBAction func backButtonTapped(_ sender: Any) {
        if let coverVC = navigationController?.viewControllers
            .compactMap({ $0 as? PhonicsCoverViewController })
            .last {

            coverVC.resumeQuestionIndex = currentIndex
        }

        goBackToPhonicsCover()
    }
}
