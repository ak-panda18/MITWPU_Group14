//
//  WordBuilder-ViewController.swift
//  Screendesigns
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class WordBuilder_ViewController: UIViewController, ExerciseReceivesCover, ExerciseResumable, ExerciseProgressReporting {
    
    // MARK: - Protocol State
    var exerciseType: ExerciseType?
    var startingIndex: Int? = nil
    var coverWasShown: Bool = false
    private(set) var questionIndex = 0
    var currentIndex: Int { questionIndex }
    
    // MARK: - Outlets
    @IBOutlet weak var feedbackLabel: UILabel!
    @IBOutlet weak var optionButton3: UIButton!
    @IBOutlet weak var optionButton2: UIButton!
    @IBOutlet weak var optionButton1: UIButton!
    @IBOutlet weak var answerView3: UIView!
    @IBOutlet weak var answerView2: UIView!
    @IBOutlet weak var answerView1: UIView!
    @IBOutlet weak var wordImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var homeButton: UIButton!
    @IBOutlet weak var submitButton: UIButton!
    
    // MARK: - Internal State
    private var question: WordBuilderQuestion?
    private var filledTiles: [Int?] = []
    private var didStyleAnswerViews = false
    private var shuffledTiles: [String] = []
    private var isAnswerLocked = false
    private var questions: [WordBuilderQuestion] = []
    
    // MARK: - Computed UI Collections
    private var answerViews: [UIView] { [answerView1, answerView2, answerView3] }
    private var optionButtons: [UIButton] { [optionButton1, optionButton2, optionButton3] }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        questions = WordBuilderQuestionLoader.loadQuestions()
        if questions.isEmpty {
            print("⚠️ No WordBuilder questions loaded")
            return
        }
        questionIndex = startingIndex ?? 0
        setupAnswerViewTapGestures()
        loadQuestion()
        submitButton.setTitle("Submit", for: .normal)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didStyleAnswerViews {
            styleAnswerViews()
            styleSubmitButton()
            didStyleAnswerViews = true
        }
    }
    
    // MARK: - Styling
    func styleAnswerViews() {
        for view in answerViews {
            view.layer.cornerRadius = view.bounds.height / 2
            view.layer.borderWidth = 2
            view.layer.borderColor = UIColor(
                red: 0.60,
                green: 0.60,
                blue: 0.60,
                alpha: 0.25
            ).cgColor
            view.clipsToBounds = true
        }
    }
    
    private func styleOptionButton(_ button: UIButton) {
        button.configuration = nil
        button.backgroundColor = UIColor(red: 1.0, green: 0.976, blue: 0.839, alpha: 1)
        button.setTitleColor(.brown, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 28, weight: .semibold)
        button.layer.cornerRadius = button.bounds.height / 2
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor(red: 0.91, green: 0.78, blue: 0.44, alpha: 1).cgColor
    }
    
    
    func styleSubmitButton() {
        submitButton.configuration = nil
        submitButton.backgroundColor = UIColor(red: 117/255,green: 80/255,blue: 50/255,alpha: 1.0)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.layer.cornerRadius = submitButton.bounds.height / 2
        submitButton.clipsToBounds = true
        submitButton.titleLabel?.font = UIFont(name: "Arial Rounded MT Bold", size: 35)
    }
    
    // MARK: - Question Loading
    func loadQuestion() {
        feedbackLabel.isHidden = true
        feedbackLabel.text = nil
        isAnswerLocked = false

        guard questions.indices.contains(questionIndex) else { return }
        let q = questions[questionIndex]
        question = q

        wordImage.image = UIImage(named: q.imageName)
        shuffledTiles = q.tiles.shuffled()
        filledTiles = Array(repeating: nil, count: q.blanksCount)

        for (i, button) in optionButtons.enumerated() {
            button.setTitle(shuffledTiles[i], for: .normal)
            button.tag = i
            button.isHidden = false
            styleOptionButton(button)
        }

        clearAllAnswerViews()
    }
    
    // MARK: - Actions
    @IBAction func optionTapped(_ sender: UIButton) {
        guard let emptyIndex = filledTiles.firstIndex(where: { $0 == nil }) else { return }

        let tileIndex = sender.tag
        let tileText = shuffledTiles[tileIndex]

        addTileText(tileText, to: answerViews[emptyIndex])
        filledTiles[emptyIndex] = tileIndex
        
        sender.isHidden = true
    }
    
    @IBAction func submitTapped(_ sender: UIButton) {

        if isAnswerLocked {
            questionIndex += 1
            if questionIndex >= questions.count {
                questionIndex = 0
            }

            submitButton.setTitle("Submit", for: .normal)
            feedbackLabel.isHidden = true
            loadQuestion()
            return
        }

        let assembled = filledTiles
            .compactMap { $0 }
            .map { shuffledTiles[$0] }
            .joined()
        guard let q = question else { return }
        if assembled.lowercased() == q.correct.lowercased() {
            feedbackLabel.text = "Correct!"
            feedbackLabel.textColor = .systemGreen
            submitButton.setTitle("Next", for: .normal)
            isAnswerLocked = true
        } else {
            feedbackLabel.text = "Try again!"
            feedbackLabel.textColor = .systemRed
        }

        feedbackLabel.isHidden = false
    }

    
    @IBAction func homeButtonTappped(_ sender: Any) {
        goHomeFromPhonics()
    }
    
    @IBAction func backButtonTapped(_ sender: Any) {
        if let coverVC = navigationController?.viewControllers
            .compactMap({ $0 as? PhonicsCoverViewController })
            .last {

            coverVC.resumeQuestionIndex = questionIndex
        }

        goBackToPhonicsCover()
    }
    
    // MARK: - Answer Handling
    func addTileText(_ text: String, to view: UIView) {
        clearAnswerView(view)

        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 30, weight: .semibold)
        label.textAlignment = .center
        label.backgroundColor = UIColor(red: 1.0, green: 0.97, blue: 0.85, alpha: 1.0)
        label.textColor = UIColor.brown
        label.layer.cornerRadius = view.bounds.height / 2
        label.layer.masksToBounds = true
        label.layer.borderWidth = 2
        label.layer.borderColor = UIColor.brown.cgColor
        label.frame = view.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        view.addSubview(label)
    }

    
    @objc func answerViewTapped(_ sender: UITapGestureRecognizer) {
        if isAnswerLocked { return }

        guard let view = sender.view else { return }
        let index = view.tag
        guard let tileIndex = filledTiles[index] else { return }

        let btn = optionButtons[tileIndex]
        btn.isHidden = false

        filledTiles[index] = nil
        clearAnswerView(view)
    }

    
    func setupAnswerViewTapGestures() {
        for (i, view) in answerViews.enumerated() {
            view.tag = i
            let tap = UITapGestureRecognizer(target: self, action: #selector(answerViewTapped(_:)))
            view.addGestureRecognizer(tap)
            view.isUserInteractionEnabled = true
        }
    }

    
    func clearAnswerView(_ view: UIView) {
        view.subviews.forEach { $0.removeFromSuperview() }
    }

    
    func clearAllAnswerViews() {
        answerViews.forEach { clearAnswerView($0) }
    }

}
