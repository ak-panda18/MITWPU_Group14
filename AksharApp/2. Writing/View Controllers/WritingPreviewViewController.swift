//
//  WritingPreviewViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit

class WritingPreviewViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var demoView: UIView!
    @IBOutlet weak var letterCardVIew: UIView!
    @IBOutlet weak var numberCardView: UIView!
    @IBOutlet weak var wordCardView: UIView!
    
    @IBOutlet weak var letterImage: UIImageView!
    @IBOutlet weak var numberImage: UIImageView!
    @IBOutlet weak var wordImage: UIImageView!
    
    @IBOutlet weak var currentLetterView: UIView!
    @IBOutlet weak var nextNumberView: UIView!
    @IBOutlet weak var nextWordView: UIView!
    @IBOutlet var currentLetterLabel: UILabel!
    @IBOutlet var currentNumberLabel: UILabel!
    @IBOutlet var currentWordLabel: UILabel!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Note: We don't need 'sync' methods anymore. The Manager is the single source of truth.
        updateCurrentLetterUI()
        updateCurrentNumberUI()
        updateCurrentWordUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        let cardStrokeColor = UIColor(red: 250/255.0, green: 239/255.0, blue: 184/255.0, alpha: 1.0)
        
        let cards = [letterCardVIew, numberCardView, wordCardView]
        cards.forEach {
            $0?.layer.borderColor = cardStrokeColor.cgColor
            $0?.layer.borderWidth = 7
            $0?.layer.cornerRadius = 25
        }
        
        let images = [letterImage, numberImage, wordImage]
        images.forEach { $0?.layer.cornerRadius = 25 }
        
        let nextViews = [currentLetterView, nextNumberView, nextWordView]
        nextViews.forEach { $0?.layer.cornerRadius = ($0?.frame.height ?? 0) / 2 }
    }
    
    private func setupGestures() {
        let letterTap = UITapGestureRecognizer(target: self, action: #selector(letterCardTapped))
        letterCardVIew.addGestureRecognizer(letterTap)
        letterCardVIew.isUserInteractionEnabled = true
        
        let numberTap = UITapGestureRecognizer(target: self, action: #selector(numberCardTapped))
        numberCardView.addGestureRecognizer(numberTap)
        numberCardView.isUserInteractionEnabled = true
    }
    
    private func updateCurrentWordUI() {
        // 1. Get Last Active Category
        let categoryString = WritingGameplayManager.shared.lastActiveCategory
        
        // 2. Load Words
        let allWords = TracingWordLoader.loadWords()
        let categoryWords = allWords.words(for: categoryString)
        
        guard !categoryWords.isEmpty else {
            currentWordLabel.text = "--"
            return
        }
        
        // 3. Get Active Index
        let activeIndex = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryString)
        let safeIndex = min(activeIndex, categoryWords.count - 1)
        
        currentWordLabel.text = categoryWords[safeIndex].word
    }

    private func updateCurrentLetterUI() {
        let index = WritingGameplayManager.shared.getHighestUnlockedIndex(category: "letters")
        
        guard index < 26 else {
            currentLetterLabel.text = "Z"
            return
        }
        let letter = String(UnicodeScalar(65 + index)!)
        currentLetterLabel.text = letter
    }
    
    private func updateCurrentNumberUI() {
        let index = WritingGameplayManager.shared.getHighestUnlockedIndex(category: "numbers")
        currentNumberLabel.text = "\(index)"
    }

    // MARK: - Actions
    @IBAction func backToHomeTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    @objc func letterCardTapped() {
        openLatest(contentType: .letters)
    }
    
    @objc func numberCardTapped() {
        openLatest(contentType: .numbers)
    }

    // MARK: - Navigation Helpers (Letters/Numbers)
    private func openLatest(contentType: WritingContentType) {
            let categoryKey = (contentType == .letters) ? "letters" : "numbers"
            let index = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
            let manager = WritingGameplayManager.shared
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc: UIViewController

            // Resume Logic (Same as WordsCategories)
            if manager.loadTwoDrawings(index: index, category: categoryKey) != nil {
                let c = storyboard.instantiateViewController(withIdentifier: "SixLetterTraceVC") as! SixLetterTraceViewController
                c.contentType = contentType
                c.currentLetterIndex = index
                vc = c
            } else if manager.loadOneDrawing(index: index, category: categoryKey) != nil {
                let c = storyboard.instantiateViewController(withIdentifier: "TwoLetterTraceVC") as! TwoLetterTraceViewController
                c.contentType = contentType
                c.currentLetterIndex = index
                vc = c
            } else {
                let c = storyboard.instantiateViewController(withIdentifier: "OneLetterTraceVC") as! OneLetterTraceViewController
                c.contentType = contentType
                c.currentLetterIndex = index
                vc = c
            }
            
            navigationController?.pushViewController(vc, animated: true)
        }
}
