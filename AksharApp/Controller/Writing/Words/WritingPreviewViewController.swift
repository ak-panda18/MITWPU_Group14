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
        let manager = TracingProgressManager.shared
        manager.syncCurrentActiveLetterWithUnlockedProgress()
        manager.syncCurrentActiveNumberWithUnlockedProgress()

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
        let manager = TracingProgressManager.shared

        let category = manager.lastActiveWordCategory

        let allWords = TracingWordLoader.loadWords()
        let categoryWords = allWords.words(for: category.rawValue)

        guard !categoryWords.isEmpty else {
            currentWordLabel.text = "--"
            return
        }

        let activeIndex = manager.getActiveWordIndex(category: category.rawValue)
        let safeIndex = min(activeIndex, categoryWords.count - 1)

        currentWordLabel.text = categoryWords[safeIndex].word
    }

    private func updateCurrentLetterUI() {
        let index = TracingProgressManager.shared.currentActiveLetterIndex

        guard index < 26 else {
            currentLetterLabel.text = "Z"
            return
        }

        let letter = String(UnicodeScalar(65 + index)!)
        currentLetterLabel.text = letter
    }
    
    private func updateCurrentNumberUI() {
        let index = TracingProgressManager.shared.currentActiveNumberIndex
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
        let index = TracingProgressManager.shared.highestUnlockedIndex(for: contentType)
        let manager = TracingProgressManager.shared
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc: UIViewController

        if manager.loadSixLetterDrawings(index: index, type: contentType) != nil {
            let c = storyboard.instantiateViewController(withIdentifier: "SixLetterTraceVC") as! SixLetterTraceViewController
            c.contentType = contentType; c.currentLetterIndex = index; vc = c
        } else if manager.isTwoLetterCompleted(index: index, type: contentType) {
            let c = storyboard.instantiateViewController(withIdentifier: "SixLetterTraceVC") as! SixLetterTraceViewController
            c.contentType = contentType; c.currentLetterIndex = index; vc = c
        } else if manager.loadOneLetterDrawing(index: index, type: contentType) != nil {
            let c = storyboard.instantiateViewController(withIdentifier: "TwoLetterTraceVC") as! TwoLetterTraceViewController
            c.contentType = contentType; c.currentLetterIndex = index; vc = c
        } else {
            let c = storyboard.instantiateViewController(withIdentifier: "OneLetterTraceVC") as! OneLetterTraceViewController
            c.contentType = contentType; c.currentLetterIndex = index; vc = c
        }
        
        navigationController?.pushViewController(vc, animated: true)
    }
}
