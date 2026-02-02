//
//  TwoWordTraceViewController.swift
//  AksharApp
//
//  Created by AksharApp on 14/01/26.
//

import UIKit
import PencilKit
import AVFoundation

class TwoWordTraceViewController: BaseTraceViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Properties
    var selectedCategory: TracingCategory = .threeLetter
    
    // Map Base Class 'currentIndex' to 'currentWordIndex'
    var currentWordIndex: Int {
        get { return currentIndex }
        set { currentIndex = newValue }
    }
    
    // Override Base Class 'categoryKey' to use the Word Category string
    override var categoryKey: String {
        return selectedCategory.rawValue
    }
    
    // Override Base Class 'brushWidth' to be dynamic based on word length
    override var brushWidth: CGFloat {
        get {
            switch selectedCategory {
            case .threeLetter: return 35.0
            case .fourLetter: return 30.0
            case .fiveLetter: return 25.0
            case .sixLetter: return 20.0
            default: return 30.0
            }
        }
        set { super.brushWidth = newValue }
    }
    
    private var words: [TracingWord] = []
    private var analyticsSessionID: UUID!
    private var didSetupAfterLayout = false

    // MARK: - Outlets
    @IBOutlet weak var yellowView: UIView!
    @IBOutlet weak var speakerButton: UIView!
    @IBOutlet weak var wordsCollectionView: UICollectionView!
    @IBOutlet weak var backChevronButton: UIButton!
    
    // MARK: - Pane Views
    @IBOutlet weak var topLetterImageView: UIImageView!
    @IBOutlet weak var topCommittedDrawingImageView: UIImageView!
    @IBOutlet weak var topTransientDrawingImageView: UIImageView! // Unused

    @IBOutlet weak var bottomLetterImageView: UIImageView!
    @IBOutlet weak var bottomCommittedDrawingImageView: UIImageView!
    @IBOutlet weak var bottomTransientDrawingImageView: UIImageView! // Unused
    
    @IBOutlet weak var nextChevronButton: UIButton!
    @IBOutlet weak var traceCompleteButton: UIButton!
    @IBOutlet weak var retryButton: UIButton!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        analyticsSessionID = UUID()
        
        // 1. Initialize Base Class logic for 2 Panes
        initPaneArrays(count: 2)
        
        // 2. Register UI components with Base Class
        // Index 0 = Top, Index 1 = Bottom
        paneLetterImageViews = [topLetterImageView, bottomLetterImageView]
        
        // 3. Setup Tracing Layers
        setupShapeLayer(for: topLetterImageView)
        setupShapeLayer(for: bottomLetterImageView)
        
        let topCanvas = setupCanvas(in: topCommittedDrawingImageView)
        let bottomCanvas = setupCanvas(in: bottomCommittedDrawingImageView)
        paneCommittedCanvases = [topCanvas, bottomCanvas]
        
        // 4. Standard UI Setup
        setupUIAppearance()
        setupCollectionView()
        loadWordsData()
        
        // 5. Load Content
        loadWord(at: currentWordIndex)
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
        // Ensure shapes align if layout changes
        if paneShapeLayers.indices.contains(1) {
            paneShapeLayers[0].frame = topLetterImageView.bounds
            paneShapeLayers[1].frame = bottomLetterImageView.bounds
        }
    }
    
    // MARK: - Setup
    private func loadWordsData() {
        let allWords = TracingWordLoader.loadWords()
        words = allWords.words(for: selectedCategory.rawValue)
    }

    private func setupCollectionView() {
        wordsCollectionView.delegate = self
        wordsCollectionView.dataSource = self
        
        if let layout = wordsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
            layout.minimumInteritemSpacing = 4
            layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
            layout.scrollDirection = .horizontal
        }
    }
    
    private func setupUIAppearance() {
        let brownColor = UIColor(red: 135/255.0, green: 87/255.0, blue: 55/255.0, alpha: 1.0).cgColor
        let yellowColor = UIColor(red: 248/255.0, green: 236/255.0, blue: 180/255.0, alpha: 1.0).cgColor
        
        func style(_ view: UIView, border: CGColor) {
            view.layer.borderColor = border
            view.layer.borderWidth = 3
        }
        
        style(speakerButton, border: brownColor)
        style(retryButton, border: brownColor)
        style(traceCompleteButton, border: brownColor)
        
        yellowView.layer.cornerRadius = 25
        wordsCollectionView.layer.borderColor = yellowColor
        wordsCollectionView.layer.borderWidth = 2
        wordsCollectionView.layer.cornerRadius = 20
        retryButton.isHidden = false
        
        nextChevronButton.isEnabled = false
        nextChevronButton.alpha = 0.4
        
        // Base handles interaction
        topLetterImageView.isUserInteractionEnabled = false
        bottomLetterImageView.isUserInteractionEnabled = false
        topCommittedDrawingImageView.isUserInteractionEnabled = false
        bottomCommittedDrawingImageView.isUserInteractionEnabled = false
    }

    // MARK: - Word Loading
    private func loadWord(at index: Int) {
        guard index < words.count else { return }
        currentWordIndex = index
        let category = categoryKey
        
        // MVC: Load Mistakes
        mistakeCount = WritingGameplayManager.shared.getMistakeCount(index: index, category: category)
        
        // 1. Load Images
        let word = words[index]
        if let image = UIImage(named: word.wordImageName) {
            topLetterImageView.image = image
            bottomLetterImageView.image = image
        }
        
        // 2. Load Masks (Both panes use the same word mask)
        let maskName = "\(word.wordImageName)_mask"
        paneMaskAssetNames = [maskName] // Store for reference
        
        loadMasks(forPane: 0, assetNames: [maskName])
        loadMasks(forPane: 1, assetNames: [maskName])
        
        // 3. MVC: Load Drawings (Tuple)
        if let (top, bottom) = WritingGameplayManager.shared.loadTwoDrawings(index: index, category: category) {
            paneCommittedCanvases[0].drawing = top
            paneCommittedCanvases[1].drawing = bottom

            // Check Top Status
            if !top.strokes.isEmpty {
                paneIsCompleted[0] = true
                paneCurrentMaskIndex[0] = 999
            } else {
                paneIsCompleted[0] = false
                paneCurrentMaskIndex[0] = 0
            }

            // Check Bottom Status
            if !bottom.strokes.isEmpty {
                paneIsCompleted[1] = true
                paneCurrentMaskIndex[1] = 999
            } else {
                paneIsCompleted[1] = false
                paneCurrentMaskIndex[1] = 0
            }
            
            // Check History (Unlock state)
            let unlockedIdx = WritingGameplayManager.shared.getHighestUnlockedIndex(category: category)
            let isHistoricallyDone = index < unlockedIdx
            
            if isHistoricallyDone {
                // If historically done, ensure visually locked even if empty (rare case)
                if !paneIsCompleted[0] { paneIsCompleted[0] = true; paneCurrentMaskIndex[0] = 999 }
                if !paneIsCompleted[1] { paneIsCompleted[1] = true; paneCurrentMaskIndex[1] = 999 }
            }
            
            isTracingLocked = false // Allow filling in gaps
        } else {
            paneCommittedCanvases[0].drawing = PKDrawing()
            paneCommittedCanvases[1].drawing = PKDrawing()
            paneIsCompleted = [false, false]
            paneCurrentMaskIndex = [0, 0]
            isTracingLocked = false
        }
        
        // Reset Transient UI
        resetTransientLayer(paneIndex: 0)
        resetTransientLayer(paneIndex: 1)
        
        wordsCollectionView.reloadData()
        updateNextChevronState()
        
        // Update Button Color
        let allDone = paneIsCompleted[0] && paneIsCompleted[1]
        traceCompleteButton.backgroundColor = allDone ? .systemGreen : .white
    }
    
    private func onAllStrokesCompleted() {
        // MVC: Save Both
        WritingGameplayManager.shared.saveTwoDrawings(
            top: paneCommittedCanvases[0].drawing,
            bottom: paneCommittedCanvases[1].drawing,
            index: currentWordIndex,
            category: categoryKey
        )
        
        nextChevronButton.isEnabled = true
        nextChevronButton.alpha = 1.0
        traceCompleteButton.backgroundColor = .systemGreen
        
        // Analytics
        let penalty = mistakeCount * 10
        let performanceScore = max(0, 100 - penalty)
        
        let session = WritingSessionData(
            id: analyticsSessionID ?? UUID(),
            date: Date(),
            childId: "default_child",
            lettersAccuracy: 0,
            wordsAccuracy: performanceScore,
            numbersAccuracy: 0
        )
        AnalyticsStore.shared.appendWritingSession(session)
        
        // Reset Mistakes
        WritingGameplayManager.shared.saveMistakeCount(0, index: currentWordIndex, category: categoryKey)
    }

    // MARK: - Actions
    @IBAction func traceCompleteTapped(_ sender: Any) {
        // Check Red Error State
        if paneShapeLayers[0].strokeColor == UIColor.red.cgColor ||
           paneShapeLayers[1].strokeColor == UIColor.red.cgColor {
            return
        }
        
        var didAdvanceTop = false
        var didAdvanceBottom = false
        
        // Process Top
        if !paneIsCompleted[0] {
            didAdvanceTop = checkAndCommitGreenInk(paneIndex: 0)
        }
        
        // Process Bottom
        if !paneIsCompleted[1] {
            didAdvanceBottom = checkAndCommitGreenInk(paneIndex: 1)
        }
        
        let topDone = paneIsCompleted[0]
        let bottomDone = paneIsCompleted[1]
        
        // Logic: Flash warning if neither advanced AND neither is done
        if !didAdvanceTop && !didAdvanceBottom {
            if !(topDone && bottomDone) {
                flashIncompleteWarning()
            }
        }
        
        // Save Progress if anything changed
        if didAdvanceTop || didAdvanceBottom {
            savePartialProgressIfNeeded()
        }
        
        // Check Full Completion
        if topDone && bottomDone {
            onAllStrokesCompleted()
            
            let penalty = mistakeCount * 10
            let accuracy = max(0, 100 - penalty)

            if accuracy >= 80 {
                showStickerFromBottom(assetName: "sticker")
            }
        }
    }
    
    @IBAction func retryTapped(_ sender: UIButton) {
        let topCompleted = paneIsCompleted[0]
        let bottomCompleted = paneIsCompleted[1]
        
        // Smart Retry: Reset only the incomplete pane
        switch (topCompleted, bottomCompleted) {
        case (true, false):
            resetPane(1)
        case (false, true):
            resetPane(0)
        case (true, true), (false, false):
            resetPane(0)
            resetPane(1)
            traceCompleteButton.backgroundColor = .white
        }
        isTracingLocked = false
    }
    
    private func resetPane(_ index: Int) {
        resetTransientLayer(paneIndex: index)
        paneCommittedCanvases[index].drawing = PKDrawing()
        paneIsCompleted[index] = false
        paneCurrentMaskIndex[index] = 0
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
        let vc = storyboard!.instantiateViewController(withIdentifier: "OneWordTraceVC") as! OneWordTraceViewController
        vc.currentWordIndex = currentWordIndex
        vc.selectedCategory = selectedCategory
        navigationController?.pushViewController(vc, animated: false)
    }
    
    @IBAction func nextChevronTapped(_ sender: Any) {
        let vc = storyboard!.instantiateViewController(withIdentifier: "SixWordTraceVC") as! SixWordTraceViewController
        vc.currentWordIndex = currentWordIndex
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
        
        // 1. History Check
        if currentWordIndex < unlocked {
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
            return
        }
        
        // 2. Current Check
        if let (top, bottom) = WritingGameplayManager.shared.loadTwoDrawings(index: currentWordIndex, category: categoryKey) {
             let isComplete = !top.strokes.isEmpty && !bottom.strokes.isEmpty
             nextChevronButton.isEnabled = isComplete
             nextChevronButton.alpha = isComplete ? 1.0 : 0.4
        } else {
             nextChevronButton.isEnabled = false
             nextChevronButton.alpha = 0.4
        }
    }
    
    private func savePartialProgressIfNeeded() {
        // Only save if there is actual content
        let topHas = !paneCommittedCanvases[0].drawing.strokes.isEmpty
        let bottomHas = !paneCommittedCanvases[1].drawing.strokes.isEmpty
        
        if topHas || bottomHas {
            WritingGameplayManager.shared.saveTwoDrawings(
                top: paneCommittedCanvases[0].drawing,
                bottom: paneCommittedCanvases[1].drawing,
                index: currentWordIndex,
                category: categoryKey
            )
        }
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
        
        if let button = cell.viewWithTag(100) as? UIButton ?? cell.contentView.subviews.first(where: { $0 is UIButton }) as? UIButton {
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
            // Navigate to OneWordTraceVC (Standard behavior for picking a specific word)
            let vc = storyboard!.instantiateViewController(withIdentifier: "OneWordTraceVC") as! OneWordTraceViewController
            vc.currentWordIndex = indexPath.item
            vc.selectedCategory = selectedCategory
            vc.modalPresentationStyle = .fullScreen
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
