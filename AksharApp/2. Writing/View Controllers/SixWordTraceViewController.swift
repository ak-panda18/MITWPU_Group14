//
//  SixWordTraceViewController.swift
//  AksharApp
//
//  Created by AksharApp on 14/01/26.
//

import UIKit
import PencilKit
import AVFoundation

class SixWordTraceViewController: BaseTraceViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Properties
    var selectedCategory: TracingCategory = .threeLetter
    var currentWordIndex: Int {
        get { return currentIndex }
        set { currentIndex = newValue }
    }
    
    override var categoryKey: String {
        return selectedCategory.rawValue
    }
    
    override var brushWidth: CGFloat {
        get {
            switch selectedCategory {
            case .threeLetter: return 15.0
            case .fourLetter: return 12.0
            case .fiveLetter: return 9.0
            case .sixLetter: return 8.0
            case .power: return 8.0
            }
        }
        set { super.brushWidth = newValue }
    }
    
    private var words: [TracingWord] = []

    // MARK: - Outlets
    @IBOutlet weak var yellowView: UIView!
    @IBOutlet weak var speakerButton: UIView!
    @IBOutlet weak var wordsCollectionView: UICollectionView!
    @IBOutlet weak var traceCompleteButton: UIButton!
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var backChevronButton: UIButton!
    @IBOutlet weak var nextChevronButton: UIButton!
    
    // MARK: - Outlets: Panes (1-6)
    @IBOutlet weak var pane1LetterImageView: UIImageView!
    @IBOutlet weak var pane1CommittedDrawingImageView: UIImageView!
    @IBOutlet weak var pane1TransientDrawingImageView: UIImageView!

    @IBOutlet weak var pane2LetterImageView: UIImageView!
    @IBOutlet weak var pane2CommittedDrawingImageView: UIImageView!
    @IBOutlet weak var pane2TransientDrawingImageView: UIImageView!
    
    @IBOutlet weak var pane3LetterImageView: UIImageView!
    @IBOutlet weak var pane3CommittedDrawingImageView: UIImageView!
    @IBOutlet weak var pane3TransientDrawingImageView: UIImageView!

    @IBOutlet weak var pane4LetterImageView: UIImageView!
    @IBOutlet weak var pane4CommittedDrawingImageView: UIImageView!
    @IBOutlet weak var pane4TransientDrawingImageView: UIImageView!

    @IBOutlet weak var pane5LetterImageView: UIImageView!
    @IBOutlet weak var pane5CommittedDrawingImageView: UIImageView!
    @IBOutlet weak var pane5TransientDrawingImageView: UIImageView!

    @IBOutlet weak var pane6LetterImageView: UIImageView!
    @IBOutlet weak var pane6CommittedDrawingImageView: UIImageView!
    @IBOutlet weak var pane6TransientDrawingImageView: UIImageView!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initPaneArrays(count: 6)
        paneLetterImageViews = [
            pane1LetterImageView, pane2LetterImageView, pane3LetterImageView,
            pane4LetterImageView, pane5LetterImageView, pane6LetterImageView
        ]
        
        let committedImageViews = [
            pane1CommittedDrawingImageView, pane2CommittedDrawingImageView, pane3CommittedDrawingImageView,
            pane4CommittedDrawingImageView, pane5CommittedDrawingImageView, pane6CommittedDrawingImageView
        ]
        for i in 0..<6 {
            setupShapeLayer(for: paneLetterImageViews[i])
            let canvas = setupCanvas(in: committedImageViews[i]!)
            paneCommittedCanvases.append(canvas)
        }
        setupUI()
        loadWordsData()
        showWord(at: currentWordIndex)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNextChevronState()
        wordsCollectionView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        savePartialProgressIfNeeded()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for i in 0..<6 {
            if paneShapeLayers.indices.contains(i) {
                paneShapeLayers[i].frame = paneLetterImageViews[i].bounds
            }
        }
    }
    
    // MARK: - Setup Methods
    private func loadWordsData() {
        let allWords = TracingWordLoader.loadWords()
        words = allWords.words(for: selectedCategory.rawValue)
    }

    private func setupUI() {
        wordsCollectionView.delegate = self
        wordsCollectionView.dataSource = self
        
        if let layout = wordsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
            layout.minimumInteritemSpacing = 4
            layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
            layout.scrollDirection = .horizontal
        }
        applyBorderStyle(to: speakerButton, borderColor: themeBrown)
        applyBorderStyle(to: retryButton, borderColor: themeBrown)
        applyBorderStyle(to: traceCompleteButton, borderColor: themeBrown)

        applyBorderStyle(
            to: wordsCollectionView,
            borderColor: themeYellow,
            borderWidth: 2,
            cornerRadius: 20
        )
        
        yellowView.layer.cornerRadius = 25
        retryButton.isHidden = false
        
        nextChevronButton.isEnabled = false
        nextChevronButton.alpha = 0.4
        
        for iv in paneLetterImageViews { iv.isUserInteractionEnabled = false }
    }
    
    // MARK: - Word Loading
    private func showWord(at index: Int) {
        guard index < words.count else { return }
        currentWordIndex = index
        let category = categoryKey
        
        let word = words[index]
        if let image = UIImage(named: word.wordImageName) {
            for iv in paneLetterImageViews { iv.image = image }
        }
        
        let maskName = "\(word.wordImageName)_mask"
        paneMaskAssetNames = [maskName]
        
        for i in 0..<6 {
            loadMasks(forPane: i, assetNames: [maskName])
        }
        
        if let savedDrawings = WritingGameplayManager.shared.loadSixDrawings(index: index, category: category),
           savedDrawings.count == 6 {
            
            for i in 0..<6 {
                paneCommittedCanvases[i].drawing = savedDrawings[i]
                if !savedDrawings[i].strokes.isEmpty {
                    paneIsCompleted[i] = true
                    paneCurrentMaskIndex[i] = 999
                } else {
                    paneIsCompleted[i] = false
                    paneCurrentMaskIndex[i] = 0
                }
            }
            
            let unlockedIdx = WritingGameplayManager.shared.getHighestUnlockedIndex(category: category)
            let isHistoricallyDone = index < unlockedIdx
            
            if isHistoricallyDone {
                 isTracingLocked = true
                 traceCompleteButton.backgroundColor = .systemGreen
            } else {
                 isTracingLocked = false
                 traceCompleteButton.backgroundColor = .white
            }
            
        } else {
            for i in 0..<6 {
                paneCommittedCanvases[i].drawing = PKDrawing()
                paneIsCompleted[i] = false
                paneCurrentMaskIndex[i] = 0
            }
            isTracingLocked = false
            traceCompleteButton.backgroundColor = .white
        }
        for i in 0..<6 { resetTransientLayer(paneIndex: i) }
        
        wordsCollectionView.reloadData()
        updateNextChevronState()
    }
    
    private func onAllStrokesCompleted() {
        let drawings = paneCommittedCanvases.map { $0.drawing }
        
        WritingGameplayManager.shared.saveSixDrawings(drawings, index: currentWordIndex, category: categoryKey)
        WritingGameplayManager.shared.finalizeSession(
            index: currentIndex,
            category: categoryKey,
            mistakes: WritingGameplayManager.shared.sessionMistakes,
            contentType: .words,
            tracingCategory: selectedCategory
        )
        
        WritingGameplayManager.shared.unlockNextItem(category: categoryKey, currentIndex: currentWordIndex)
        
        wordsCollectionView.reloadData()
        nextChevronButton.isEnabled = true
        nextChevronButton.alpha = 1.0
        traceCompleteButton.backgroundColor = .systemGreen
        
        WritingGameplayManager.shared.saveMistakeCount(0, index: currentWordIndex, category: categoryKey)
        
        isTracingLocked = true
    }

    // MARK: - Actions
    @IBAction func traceCompleteTapped(_ sender: Any) {
        for i in 0..<6 {
            if paneShapeLayers[i].strokeColor == UIColor.red.cgColor { return }
        }
        
        var didAdvanceAny = false
        for i in 0..<6 {
            if !paneIsCompleted[i] {
                let advanced = checkAndCommitGreenInk(paneIndex: i)
                if advanced { didAdvanceAny = true }
            }
        }
        
        if didAdvanceAny {
            savePartialProgressIfNeeded()
        }
        
        let fullyComplete = paneIsCompleted.allSatisfy { $0 == true }
        
        if fullyComplete {
            onAllStrokesCompleted()
            if WritingGameplayManager.shared.didEarnSticker() {
                showStickerFromBottom(assetName: "sticker")
            }
        } else if !didAdvanceAny {
            flashIncompleteWarning()
        }
    }
    
    @IBAction func retryTapped(_ sender: UIButton) {
        let completedCount = paneIsCompleted.filter { $0 }.count

        if completedCount > 0 && completedCount < 6 {
            for i in 0..<6 where !paneIsCompleted[i] {
                resetPane(i)
            }
        } else {
            for i in 0..<6 {
                resetPane(i)
            }
            traceCompleteButton.backgroundColor = .white
        }
        isTracingLocked = false
    }
    
    private func resetPane(_ index: Int) {
        resetPaneCompletely(index)
    }
    
    @IBAction func backButtonTapped(_ sender: Any) {
        if let nav = navigationController {
            for controller in nav.viewControllers {
                if String(describing: type(of: controller)).contains("WordsCategories") {
                    nav.popToViewController(controller, animated: true)
                    return
                }
            }
            nav.popViewController(animated: true)
        }
    }

    @IBAction func homeButtonTapped(_ sender: UIButton) {
        navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func backTapped(_ sender: UIButton) {
        let vc = storyboard!.instantiateViewController(withIdentifier: "TwoWordTraceVC") as! TwoWordTraceViewController
        vc.currentWordIndex = currentWordIndex
        vc.selectedCategory = selectedCategory
        navigationController?.pushViewController(vc, animated: false)
    }

    @IBAction func nextChevronTapped(_ sender: Any) {
        let vc = storyboard!.instantiateViewController(withIdentifier: "OneWordTraceVC") as! OneWordTraceViewController
        vc.currentWordIndex = currentWordIndex + 1
        vc.selectedCategory = selectedCategory
        navigationController?.pushViewController(vc, animated: false)
    }
    

    @IBAction func speakerTapped(_ sender: Any) {
        guard currentWordIndex < words.count else { return }
        let word = words[currentWordIndex].word
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
    
    // MARK: - Helpers
    private func updateNextChevronState() {
        let unlocked = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
        
        if currentWordIndex < unlocked {
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
            return
        }
        
        if let drawings = WritingGameplayManager.shared.loadSixDrawings(index: currentWordIndex, category: categoryKey) {
             let isComplete = drawings.allSatisfy { !$0.strokes.isEmpty }
             nextChevronButton.isEnabled = isComplete
             nextChevronButton.alpha = isComplete ? 1.0 : 0.4
        } else {
             nextChevronButton.isEnabled = false
             nextChevronButton.alpha = 0.4
        }
    }
    
    private func savePartialProgressIfNeeded() {
        let anyStrokes = paneCommittedCanvases.contains { !$0.drawing.strokes.isEmpty }
        guard anyStrokes else { return }
        
        let drawings = paneCommittedCanvases.map { $0.drawing }
        WritingGameplayManager.shared.saveSixDrawings(drawings, index: currentWordIndex, category: categoryKey)
    }
    
    private func flashIncompleteWarning() {
        let originalColor = traceCompleteButton.backgroundColor
        UIView.animate(withDuration: 0.1, animations: {
            self.traceCompleteButton.backgroundColor = .systemOrange
            self.traceCompleteButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.traceCompleteButton.backgroundColor = originalColor
                self.traceCompleteButton.transform = .identity
            }
        }
    }
    
    // MARK: - CollectionView DataSource & Delegate
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return words.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "wordButtonCell", for: indexPath)
        
        if let button = cell.viewWithTag(100) as? UIButton  {
            let word = words[indexPath.item].word
            
            button.configuration = nil
            button.setTitle(word, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 30, weight: .medium)
            
            let unlockedIdx = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
            let isUnlocked = indexPath.item <= unlockedIdx
            let isCompleted = indexPath.item < unlockedIdx
            
            if isCompleted {
                button.backgroundColor = .systemGreen; button.setTitleColor(.white, for: .normal)
            } else if isUnlocked {
                button.backgroundColor = .systemBlue; button.setTitleColor(.white, for: .normal)
            } else {
                button.backgroundColor = .lightGray; button.setTitleColor(.darkGray, for: .normal)
            }
            
            button.layer.cornerRadius = 30
            button.clipsToBounds = true
            button.isUserInteractionEnabled = false // Let cell handle touch
            
            if indexPath.item == currentWordIndex {
                button.layer.borderWidth = 3; button.layer.borderColor = UIColor.white.cgColor
            } else {
                button.layer.borderWidth = 0
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let unlockedIdx = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
        
        if indexPath.item <= unlockedIdx {
            let vc = storyboard!.instantiateViewController(withIdentifier: "OneWordTraceVC") as! OneWordTraceViewController
            vc.currentWordIndex = indexPath.item
            vc.selectedCategory = selectedCategory
            navigationController?.pushViewController(vc, animated: false)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let word = words[indexPath.item].word
        let font = UIFont.systemFont(ofSize: 30, weight: .medium)
        let textSize = (word as NSString).size(withAttributes: [.font: font])
        return CGSize(width: max(textSize.width + 32, 100), height: textSize.height + 24)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 4
    }
}
