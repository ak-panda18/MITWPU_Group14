//
//  OneWordTraceViewController.swift
//  AksharApp
//
//  Created by AksharApp on 14/01/26.
//

import UIKit
import PencilKit
import AVFoundation

class OneWordTraceViewController: BaseTraceViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Properties
    var selectedCategory: TracingCategory = .threeLetter
    
    // Map Base Class 'currentIndex' to 'currentWordIndex'
    var currentWordIndex: Int {
        get { return currentIndex }
        set { currentIndex = newValue }
    }
    
    // Override Base Class 'categoryKey' to use the Word Category string (e.g., "3-letter", "power")
    // This ensures mistakes/progress are saved to the correct category.
    override var categoryKey: String {
        return selectedCategory.rawValue
    }
    
    // Override Base Class 'brushWidth' to be dynamic based on word length
    override var brushWidth: CGFloat {
        get {
            switch selectedCategory {
            case .threeLetter: return 40.0
            case .fourLetter: return 45.0
            case .fiveLetter: return 30.0
            case .sixLetter: return 25.0
            default: return 40.0
            }
        }
        set { super.brushWidth = newValue } // Setter placeholder
    }
    
    private var words: [TracingWord] = []
    private var powerWordCenterConstraints: [NSLayoutConstraint] = []
    private var didSetupAfterLayout = false
    
    // MARK: - Outlets
    @IBOutlet weak var tracingStackView: UIStackView!
    @IBOutlet weak var wordsCollectionView: UICollectionView!
    @IBOutlet weak var yellowView: UIView!
    @IBOutlet weak var speakerButton: UIView!
    @IBOutlet weak var wordImageView: UIImageView!
    @IBOutlet weak var committedDrawingImageView: UIImageView!
    @IBOutlet weak var illustrationImageView: UIImageView! // Specific to Words
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var tickButton: UIButton!
    @IBOutlet weak var nextChevronButton: UIButton!
    @IBOutlet weak var backChevronButton: UIButton!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. Initialize Base Class logic for 1 Pane
        initPaneArrays(count: 1)
        
        // 2. Register UI components
        paneLetterImageViews = [wordImageView]
        
        // 3. Setup Tracing Layers
        setupShapeLayer(for: wordImageView)
        let canvas = setupCanvas(in: committedDrawingImageView)
        paneCommittedCanvases = [canvas]
        
        // 4. Standard UI & Data Setup
        setupUI()
        loadWordsData()
        
        // 5. Layout (Defer specific layout updates until needed)
        if !didSetupAfterLayout {
            applyPowerWordLayoutIfNeeded()
            didSetupAfterLayout = true
        }
        
        // 6. Load Content
        showWord(at: currentWordIndex)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateChevronStates()
        wordsCollectionView.reloadData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure shapes align if layout changes (e.g. rotation)
        if paneShapeLayers.indices.contains(0) {
            paneShapeLayers[0].frame = wordImageView.bounds
        }
    }
    
    // MARK: - Setup Methods
    private func loadWordsData() {
        let allWords = TracingWordLoader.loadWords()
        words = allWords.words(for: selectedCategory.rawValue)
    }
    
    private func setupUI() {
        wordsCollectionView.dataSource = self
        wordsCollectionView.delegate = self
        
        if let layout = wordsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
            layout.minimumInteritemSpacing = 4
            layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
            layout.scrollDirection = .horizontal
        }
        
        let brown = UIColor(red: 135/255.0, green: 87/255.0, blue: 55/255.0, alpha: 1.0)
        let yellow = UIColor(red: 248/255.0, green: 236/255.0, blue: 180/255.0, alpha: 1.0)
        
        func style(_ view: UIView, border: CGColor) {
            view.layer.borderColor = border
            view.layer.borderWidth = 3
        }
        
        style(speakerButton, border: brown.cgColor)
        style(retryButton, border: brown.cgColor)
        style(tickButton, border: brown.cgColor)
        
        yellowView.layer.cornerRadius = 25
        wordsCollectionView.layer.borderColor = yellow.cgColor
        wordsCollectionView.layer.borderWidth = 2
        wordsCollectionView.layer.cornerRadius = 20
        
        illustrationImageView.layer.cornerRadius = 15
        illustrationImageView.clipsToBounds = true
        illustrationImageView.contentMode = .scaleAspectFit
        
        // Base handles touch, disable local interaction
        wordImageView.isUserInteractionEnabled = false
        wordImageView.contentMode = .scaleAspectFit
        committedDrawingImageView.isUserInteractionEnabled = false
        committedDrawingImageView.backgroundColor = .clear
        
        nextChevronButton.isEnabled = false
        nextChevronButton.alpha = 0.4
        
        // Speaker Tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(speakerTapped))
        speakerButton.addGestureRecognizer(tap)
        speakerButton.isUserInteractionEnabled = true
    }
    
    private func applyPowerWordLayoutIfNeeded() {
        guard selectedCategory == .power else { return }
        illustrationImageView.isHidden = true
        wordImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Remove old constraints on illustration/word stack if possible,
        // but here we just re-constrain wordImageView to center.
        let constraintsToDeactivate = yellowView.constraints.filter {
            $0.firstItem as? UIView == wordImageView ||
            $0.secondItem as? UIView == wordImageView
        }
        NSLayoutConstraint.deactivate(constraintsToDeactivate)
        
        let centerX = wordImageView.centerXAnchor.constraint(equalTo: yellowView.centerXAnchor)
        let centerY = wordImageView.centerYAnchor.constraint(equalTo: yellowView.centerYAnchor)
        let maxWidth = wordImageView.widthAnchor.constraint(lessThanOrEqualTo: yellowView.widthAnchor, multiplier: 0.85)
        let maxHeight = wordImageView.heightAnchor.constraint(lessThanOrEqualTo: yellowView.heightAnchor, multiplier: 0.6)
        
        powerWordCenterConstraints = [centerX, centerY, maxWidth, maxHeight]
        NSLayoutConstraint.activate(powerWordCenterConstraints)
    }

    // MARK: - Content Loading
    private func showWord(at index: Int) {
        guard index < words.count else { return }
        currentWordIndex = index
        let category = categoryKey // Uses our override
        
        // MVC: Load Mistakes
        mistakeCount = WritingGameplayManager.shared.getMistakeCount(index: index, category: category)
        
        let wordData = words[index]
        
        // 1. Load Images
        if let image = UIImage(named: wordData.wordImageName) {
            wordImageView.image = image
        }
        
        if let illustrationName = wordData.imageName {
            illustrationImageView.image = UIImage(named: illustrationName)
        } else {
            illustrationImageView.image = nil
        }
        
        // 2. Load Mask
        // Base Class helper 'loadMasks' expects an array
        paneMaskAssetNames = ["\(wordData.wordImageName)_mask"]
        loadMasks(forPane: 0, assetNames: paneMaskAssetNames)
        
        // 3. MVC: Load Saved Drawing
        if let savedDrawing = WritingGameplayManager.shared.loadOneDrawing(index: index, category: category) {
            paneCommittedCanvases[0].drawing = savedDrawing
            let hasContent = !savedDrawing.strokes.isEmpty
            
            // Logic: Is this word historically done?
            let maxUnlocked = WritingGameplayManager.shared.getHighestUnlockedIndex(category: category)
            let isHistoricallyDone = (index < maxUnlocked)
            
            if (isHistoricallyDone && hasContent) || hasContent {
                paneIsCompleted[0] = true
                paneCurrentMaskIndex[0] = 999 // Force Complete
                isTracingLocked = true
                tickButton.backgroundColor = .systemGreen
            } else {
                paneIsCompleted[0] = false
                paneCurrentMaskIndex[0] = 0
                isTracingLocked = false
                tickButton.backgroundColor = .white
            }
        } else {
            paneCommittedCanvases[0].drawing = PKDrawing()
            paneIsCompleted[0] = false
            paneCurrentMaskIndex[0] = 0
            isTracingLocked = false
            tickButton.backgroundColor = .white
        }
        
        resetTransientLayer(paneIndex: 0)
        updateChevronStates()
        wordsCollectionView.reloadData()
    }
    
    private func onAllStrokesCompleted() {
        paneIsCompleted[0] = true
        isTracingLocked = true
        resetTransientLayer(paneIndex: 0)
        tickButton.backgroundColor = .systemGreen
        
        // MVC: Save Drawing (Auto-unlocks next word inside Manager if logic existed there,
        // but for Words, usually only 'SixWord' stage unlocks next.
        // However, we save the drawing state here.)
        WritingGameplayManager.shared.saveOneDrawing(
            paneCommittedCanvases[0].drawing,
            index: currentWordIndex,
            category: categoryKey
        )
        
        // Analytics
        let penalty = mistakeCount * 10
        let performanceScore = max(0, 100 - penalty)
        
        let session = WritingSessionData(
            id: UUID(),
            date: Date(),
            childId: "default_child",
            lettersAccuracy: 0,
            wordsAccuracy: performanceScore,
            numbersAccuracy: 0
        )
        AnalyticsStore.shared.appendWritingSession(session)
        
        // Reset Mistakes
        WritingGameplayManager.shared.saveMistakeCount(0, index: currentWordIndex, category: categoryKey)
        
        updateChevronStates()
        
        if performanceScore >= 80 {
            showStickerFromBottom(assetName: "sticker")
        }
    }

    // MARK: - Actions
    @IBAction func traceCompleteTapped(_ sender: Any) {
        if isTracingLocked && !paneIsCompleted[0] { return }

        // Base Class Logic
        let didAdvance = checkAndCommitGreenInk(paneIndex: 0)

        if paneIsCompleted[0] {
            onAllStrokesCompleted()
        } else if !didAdvance {
            flashIncompleteWarning()
        }
        
        // Intermediate Save if progressed
        if didAdvance && !paneIsCompleted[0] {
            WritingGameplayManager.shared.saveOneDrawing(
                paneCommittedCanvases[0].drawing,
                index: currentWordIndex,
                category: categoryKey
            )
        }
    }
    
    @IBAction func retryButtonTapped(_ sender: UIButton) {
        // Clear UI only, keep file on disk
        isTracingLocked = false
        paneIsCompleted[0] = false
        paneCurrentMaskIndex[0] = 0
        tickButton.backgroundColor = .white

        resetTransientLayer(paneIndex: 0)
        paneCommittedCanvases[0].drawing = PKDrawing()
        
        // No need to update chevrons because the file remains on disk
    }
    
    @IBAction func speakerTapped(_ sender: UIButton) {
        guard currentWordIndex < words.count else { return }
        let textToSpeak = words[currentWordIndex].word
        
        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
    
    @IBAction func backTapped(_ sender: UIButton) {
        if currentWordIndex > 0 {
            let vc = storyboard!.instantiateViewController(withIdentifier: "SixWordTraceVC") as! SixWordTraceViewController
            vc.currentWordIndex = currentWordIndex - 1
            vc.selectedCategory = selectedCategory
            navigationController?.pushViewController(vc, animated: false)
        }
    }
    
    @IBAction func nextChevronTapped(_ sender: UIButton) {
        let vc = storyboard!.instantiateViewController(withIdentifier: "TwoWordTraceVC") as! TwoWordTraceViewController
        vc.currentWordIndex = currentWordIndex
        vc.selectedCategory = selectedCategory
        navigationController?.pushViewController(vc, animated: false)
    }
    
    @IBAction func homeButtonTapped(_ sender: UIButton) {
        navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func backButtonTapped(_ sender: Any) {
        // Find WordsCategoriesViewController in stack
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

    // MARK: - Helpers
    private func updateChevronStates() {
        let unlocked = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
        
        // 1. History Check
        if currentWordIndex < unlocked {
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
            backChevronButton.isEnabled = (currentWordIndex > 0)
            backChevronButton.alpha = (currentWordIndex > 0) ? 1.0 : 0.4
            return
        }
        
        // 2. Current Check
        let hasSavedDrawing = (WritingGameplayManager.shared.loadOneDrawing(index: currentWordIndex, category: categoryKey) != nil)
        
        nextChevronButton.isEnabled = hasSavedDrawing
        nextChevronButton.alpha = hasSavedDrawing ? 1.0 : 0.4
        
        backChevronButton.isEnabled = (currentWordIndex > 0)
        backChevronButton.alpha = (currentWordIndex > 0) ? 1.0 : 0.4
    }
    
    private func flashIncompleteWarning() {
        let originalColor = tickButton.backgroundColor
        UIView.animate(withDuration: 0.1, animations: {
            self.tickButton.backgroundColor = .systemOrange
            self.tickButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.tickButton.backgroundColor = originalColor
                self.tickButton.transform = .identity
            }
        }
    }
    
    // MARK: - CollectionView DataSource & Delegate
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return words.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "wordButtonCell", for: indexPath)
        
        if let button = cell.viewWithTag(100) as? UIButton {
            let word = words[indexPath.item].word
            button.setTitle(word, for: .normal)
            
            let unlockedIdx = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
            let isUnlocked = indexPath.item <= unlockedIdx
            let isCompleted = indexPath.item < unlockedIdx
            
            if isCompleted {
                button.backgroundColor = .systemGreen
                button.setTitleColor(.white, for: .normal)
            } else if isUnlocked {
                button.backgroundColor = .systemBlue
                button.setTitleColor(.white, for: .normal)
            } else {
                button.backgroundColor = .lightGray
                button.setTitleColor(.darkGray, for: .normal)
            }
            
            if indexPath.item == currentWordIndex {
                button.layer.borderWidth = 3
                button.layer.borderColor = UIColor.white.cgColor
            } else {
                button.layer.borderWidth = 0
            }
            
            // Disable interaction so cell handles selection
            button.isUserInteractionEnabled = false
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let unlockedIdx = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
        
        if indexPath.item <= unlockedIdx {
            showWord(at: indexPath.item)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard indexPath.item < words.count else { return CGSize(width: 100, height: 60) }
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
