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
            case .threeLetter: return 32.0
            case .fourLetter: return 27.0
            case .fiveLetter: return 22.0
            case .sixLetter: return 13.0
            case .power: return 13.0
            }
        }
        set { super.brushWidth = newValue }
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
    @IBOutlet weak var illustrationImageView: UIImageView!
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var tickButton: UIButton!
    @IBOutlet weak var nextChevronButton: UIButton!
    @IBOutlet weak var backChevronButton: UIButton!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        WritingGameplayManager.shared.lastActiveCategory = selectedCategory.rawValue
        
        initPaneArrays(count: 1)
        
        paneLetterImageViews = [wordImageView]
        
        setupShapeLayer(for: wordImageView)
        let canvas = setupCanvas(in: committedDrawingImageView)
        paneCommittedCanvases = [canvas]
        
        setupUI()
        loadWordsData()
        
        if !didSetupAfterLayout {
            applyPowerWordLayoutIfNeeded()
            didSetupAfterLayout = true
        }
        
        showWord(at: currentWordIndex)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateChevronStates()
        wordsCollectionView.reloadData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
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
        
        applyBorderStyle(to: speakerButton, borderColor: themeBrown)
        applyBorderStyle(to: retryButton, borderColor: themeBrown)
        applyBorderStyle(to: tickButton, borderColor: themeBrown)

        applyBorderStyle(
            to: wordsCollectionView,
            borderColor: themeYellow,
            borderWidth: 2,
            cornerRadius: 20
        )

        yellowView.layer.cornerRadius = 25

        
        illustrationImageView.layer.cornerRadius = 15
        illustrationImageView.clipsToBounds = true
        illustrationImageView.contentMode = .scaleAspectFit
        
        wordImageView.isUserInteractionEnabled = false
        wordImageView.contentMode = .scaleAspectFit
        committedDrawingImageView.isUserInteractionEnabled = false
        committedDrawingImageView.backgroundColor = .clear
        
        nextChevronButton.isEnabled = false
        nextChevronButton.alpha = 0.4
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(speakerTapped))
        speakerButton.addGestureRecognizer(tap)
        speakerButton.isUserInteractionEnabled = true
    }
    
    private func applyPowerWordLayoutIfNeeded() {
        guard selectedCategory == .power else { return }
        illustrationImageView.isHidden = true
        
        wordImageView.translatesAutoresizingMaskIntoConstraints = false
        committedDrawingImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let constraintsToDeactivate = yellowView.constraints.filter {
            $0.firstItem as? UIView == wordImageView ||
            $0.secondItem as? UIView == wordImageView ||
            $0.firstItem as? UIView == committedDrawingImageView ||
            $0.secondItem as? UIView == committedDrawingImageView
        }
        NSLayoutConstraint.deactivate(constraintsToDeactivate)
        
        let centerX = wordImageView.centerXAnchor.constraint(equalTo: yellowView.centerXAnchor)
        let centerY = wordImageView.centerYAnchor.constraint(equalTo: yellowView.centerYAnchor)
        let maxWidth = wordImageView.widthAnchor.constraint(lessThanOrEqualTo: yellowView.widthAnchor, multiplier: 0.85)
        let maxHeight = wordImageView.heightAnchor.constraint(lessThanOrEqualTo: yellowView.heightAnchor, multiplier: 0.6)
        
        let matchTop = committedDrawingImageView.topAnchor.constraint(equalTo: wordImageView.topAnchor)
        let matchBottom = committedDrawingImageView.bottomAnchor.constraint(equalTo: wordImageView.bottomAnchor)
        let matchLeading = committedDrawingImageView.leadingAnchor.constraint(equalTo: wordImageView.leadingAnchor)
        let matchTrailing = committedDrawingImageView.trailingAnchor.constraint(equalTo: wordImageView.trailingAnchor)
        
        powerWordCenterConstraints = [
            centerX, centerY, maxWidth, maxHeight,
            matchTop, matchBottom, matchLeading, matchTrailing
        ]
        NSLayoutConstraint.activate(powerWordCenterConstraints)
        view.layoutIfNeeded()
        if paneCommittedCanvases.indices.contains(0) {
            paneCommittedCanvases[0].frame = committedDrawingImageView.bounds
        }
    }

    // MARK: - Content Loading
    private func showWord(at index: Int) {
        guard index < words.count else { return }
        currentWordIndex = index
        let category = categoryKey
        
        let wordData = words[index]
        let content =
            WordTraceContentProvider.content(
                word: wordData
            )

        wordImageView.image = content.0
        illustrationImageView.image = content.1

        paneMaskAssetNames = content.2
        loadMasks(forPane: 0, assetNames: paneMaskAssetNames)
        restoreWordDrawing(
            index: index,
            category: category
        )

        tickButton.backgroundColor =
        paneIsCompleted[0] ? .systemGreen : .white
        
        resetTransientLayer(paneIndex: 0)
        updateChevronStates()
        wordsCollectionView.reloadData()
    }
    
    private func restoreWordDrawing(
        index: Int,
        category: String
    ) {

        if let saved =
            WritingGameplayManager.shared
            .loadOneDrawing(
                index: index,
                category: category
            ) {

            paneCommittedCanvases[0].drawing = saved

            let hasContent = !saved.strokes.isEmpty

            paneIsCompleted[0] = hasContent
            paneCurrentMaskIndex[0] =
                hasContent ? 999 : 0

            isTracingLocked = hasContent

        } else {
            paneCommittedCanvases[0].drawing =
                PKDrawing()

            paneIsCompleted[0] = false
            paneCurrentMaskIndex[0] = 0
            isTracingLocked = false
        }
    }
    
    private func onAllStrokesCompleted() {
        paneIsCompleted[0] = true
        isTracingLocked = true
        resetTransientLayer(paneIndex: 0)
        tickButton.backgroundColor = .systemGreen
        
        WritingGameplayManager.shared.saveOneDrawing(
            paneCommittedCanvases[0].drawing,
            index: currentWordIndex,
            category: categoryKey
        )
        WritingGameplayManager.shared.finalizeSession(
            index: currentIndex,
            category: categoryKey,
            mistakes: WritingGameplayManager.shared.sessionMistakes,
            contentType: .words,
            tracingCategory: selectedCategory
        )
        
        WritingGameplayManager.shared.saveMistakeCount(0, index: currentWordIndex, category: categoryKey)
        
        updateChevronStates()
    }

    // MARK: - Actions
    @IBAction func traceCompleteTapped(_ sender: Any) {
        if isTracingLocked && !paneIsCompleted[0] { return }
        let didAdvance = checkAndCommitGreenInk(paneIndex: 0)

        if paneIsCompleted[0] {
            onAllStrokesCompleted()
            if WritingGameplayManager.shared.didEarnSticker() {
                showStickerFromBottom(assetName: "sticker")
            }
        } else if !didAdvance {
            flashIncompleteWarning()
        }
        
        if didAdvance && !paneIsCompleted[0] {
            WritingGameplayManager.shared.saveOneDrawing(
                paneCommittedCanvases[0].drawing,
                index: currentWordIndex,
                category: categoryKey
            )
        }
    }
    
    @IBAction func retryButtonTapped(_ sender: UIButton) {
        isTracingLocked = false
        tickButton.backgroundColor = .white
        resetPaneCompletely(0)
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
        
        if currentWordIndex < unlocked {
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
            backChevronButton.isEnabled = (currentWordIndex > 0)
            backChevronButton.alpha = (currentWordIndex > 0) ? 1.0 : 0.4
            return
        }
        
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
            button.configuration = nil
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 30, weight: .medium)
            button.titleLabel?.textAlignment = .center
            let word = words[indexPath.item].word
            button.setTitle(word, for: .normal)
            let unlockedIdx =
            WritingGameplayManager.shared
            .getHighestUnlockedIndex(category: categoryKey)

            let isUnlocked =
            WritingGameplayManager.shared
            .isIndexUnlocked(
                index: indexPath.item,
                category: categoryKey
            )

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
            
            button.layoutIfNeeded()
            button.layer.cornerRadius = button.bounds.height / 2
            button.clipsToBounds = true
            button.isUserInteractionEnabled = false
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard WritingGameplayManager.shared.isIndexUnlocked(
            index: indexPath.item,
            category: categoryKey
        ) else { return }

        showWord(at: indexPath.item)
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
