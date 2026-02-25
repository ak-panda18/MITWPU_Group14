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
    
    @IBOutlet weak var letterProgressView: UIProgressView!
    @IBOutlet var numberProgressView: UIProgressView!
    @IBOutlet weak var wordProgressView: UIProgressView!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        bindUI()
    }
    // MARK: - UI Binding
    private func bindUI() {
        let manager = WritingGameplayManager.shared
        
        currentLetterLabel.text = manager.currentLetterDisplay()
        currentNumberLabel.text = manager.currentNumberDisplay()
        currentWordLabel.text = manager.currentWordDisplay()
        
        letterProgressView.progress = manager.letterProgress()
        numberProgressView.progress = manager.numberProgress()
        wordProgressView.progress = manager.wordProgress()
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
        
        WritingGameplayManager.shared.lastActiveCategory = categoryKey
        
            let index = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
            let manager = WritingGameplayManager.shared
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc: UIViewController

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
