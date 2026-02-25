//
//  OneLetterTraceViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit
import PencilKit
import AVFoundation

class OneLetterTraceViewController: BaseTraceViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Properties
    
    var currentLetterIndex: Int {
        get { return currentIndex }
        set { currentIndex = newValue }
    }
    
    // MARK: - Outlets
    @IBOutlet weak var yellowView: UIView!
    @IBOutlet weak var speakerButton: UIView!
    @IBOutlet weak var alphabetCollectionView: UICollectionView!
    @IBOutlet weak var nextChevronButton: UIButton!
    @IBOutlet weak var backChevronButton: UIButton!
    @IBOutlet weak var tickButton: UIButton!
    @IBOutlet weak var letterImageView: UIImageView!
    @IBOutlet weak var committedDrawingImageView: UIImageView!
    @IBOutlet weak var transientDrawingImageView: UIImageView!
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    override var traceStage: String { return "one" }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.brushWidth = 55
        WritingGameplayManager.shared.startNewSession()
        initPaneArrays(count: 1)
        
        paneLetterImageViews = [letterImageView]
        
        setupShapeLayer(for: letterImageView)
        
        let canvas = setupCanvas(in: committedDrawingImageView)
        paneCommittedCanvases = [canvas]
        
        setupUIAppearance()
        setupCollectionView()
        
        showLetter(at: currentIndex)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateChevronStates()
        alphabetCollectionView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startTraceAnimationForPane0(force: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTraceAnimation()
    }

    // MARK: - UI Setup
    private func setupCollectionView() {
        alphabetCollectionView.delegate = self
        alphabetCollectionView.dataSource = self
        
        if let layout = alphabetCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        }
    }
    
    private func setupUIAppearance() {
        applyBorderStyle(to: speakerButton, borderColor: themeBrown)
        applyBorderStyle(to: retryButton, borderColor: themeBrown)
        applyBorderStyle(to: tickButton, borderColor: themeBrown)
        applyBorderStyle(to: playButton, borderColor: themeBrown)

        applyBorderStyle(
            to: alphabetCollectionView,
            borderColor: themeYellow,
            borderWidth: 2,
            cornerRadius: 20
        )
        
        yellowView.layer.cornerRadius = 25
        retryButton.isHidden = false
        
        
        nextChevronButton.isEnabled = false
        nextChevronButton.alpha = 0.4
        
        letterImageView.isUserInteractionEnabled = false
        letterImageView.contentMode = .scaleAspectFit
        committedDrawingImageView.isUserInteractionEnabled = false
        committedDrawingImageView.backgroundColor = .clear
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(speakerButtonTapped))
        speakerButton.addGestureRecognizer(tap)
        speakerButton.isUserInteractionEnabled = true
    }

    // MARK: - Content Loading
    private func showLetter(at index: Int) {
        currentIndex = index
        let category = categoryKey

        
        let (paneImages, maskNames) = TraceContentProvider.paneImages(
                    index: index,
                    contentType: contentType
                )

        letterImageView.image = paneImages[0]
        paneMaskAssetNames = maskNames
        
        loadMasks(forPane: 0, assetNames: paneMaskAssetNames)
        
        if let savedDrawing = WritingGameplayManager.shared.loadOneDrawing(index: index, category: category) {
            paneCommittedCanvases[0].drawing = savedDrawing
        let hasContent = !savedDrawing.strokes.isEmpty
            
        if (hasContent){
            paneIsCompleted[0] = true
            paneCurrentMaskIndex[0] = 999
            isTracingLocked = true
        } else {
            paneIsCompleted[0] = false
            paneCurrentMaskIndex[0] = 0
            isTracingLocked = false
        }
        } else {
            paneCommittedCanvases[0].drawing = PKDrawing()
            paneIsCompleted[0] = false
            paneCurrentMaskIndex[0] = 0
            isTracingLocked = false
        }
        
        resetTransientLayer(paneIndex: 0)
        updateChevronStates()
        alphabetCollectionView.reloadData()
    }
    
    private func onAllStrokesCompleted() {
        paneIsCompleted[0] = true
        isTracingLocked = true
        resetTransientLayer(paneIndex: 0)
        
        WritingGameplayManager.shared.saveOneDrawing(
            paneCommittedCanvases[0].drawing,
            index: currentIndex,
            category: categoryKey
        )
        WritingGameplayManager.shared.finalizeSession(
            index: currentIndex,
            category: categoryKey,
            mistakes: WritingGameplayManager.shared.sessionMistakes,
            contentType: contentType
        )
        
        nextChevronButton.isEnabled = true
        nextChevronButton.alpha = 1.0
        view.bringSubviewToFront(nextChevronButton)
    }

    // MARK: - Actions
    @IBAction func traceCompleteTapped(_ sender: Any) {
        if isTracingLocked && !paneIsCompleted[0] { return }
            if paneIsCompleted[0] { return }

            let didAdvance = checkAndCommitGreenInk(paneIndex: 0)

            if paneIsCompleted[0] {
                onAllStrokesCompleted()
                if WritingGameplayManager.shared.didEarnSticker()  {
                    showStickerFromBottom(assetName: "sticker")
                }
            } else if !didAdvance {
                flashIncompleteWarning()
            }
    }
    
    @IBAction func playTapped(_ sender: UIButton) {
        startTraceAnimationForPane0(force: false)
    }
    
    @IBAction func retryTapped(_ sender: UIButton) {
        isTracingLocked = false
        resetPaneCompletely(0)
        
    }
    
    @IBAction func speakerButtonTapped(_ sender: Any) {
        let textToSpeak: String
        switch contentType {
        case .words: fatalError("Words not supported in OneLetterTraceViewController")
        case .letters:
            textToSpeak = WritingGameplayManager.shared.getCharacterString(
                for: currentIndex,
                contentType: contentType
            )
        case .numbers:
            textToSpeak = "\(currentIndex)"
        }
        
        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
    
    @IBAction func letterButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard WritingGameplayManager.shared.isIndexUnlocked(index: index, category: categoryKey) else { return }

        let vc = storyboard!.instantiateViewController(withIdentifier: "OneLetterTraceVC") as! OneLetterTraceViewController
        vc.contentType = contentType
        vc.currentLetterIndex = index
        navigationController?.pushViewController(vc, animated: false)
    }
    
    @IBAction func nextChevronTapped(_ sender: UIButton) {
        let vc = storyboard!.instantiateViewController(withIdentifier: "TwoLetterTraceVC") as! TwoLetterTraceViewController
        vc.contentType = contentType
        vc.currentLetterIndex = currentIndex
        navigationController?.pushViewController(vc, animated: false)

    }
    
    @IBAction func previousChevronTapped(_ sender: UIButton) {
        guard currentIndex > 0 else { return }
        
        let targetIndex = currentIndex - 1
        if let nav = navigationController,
           let prevVC = nav.viewControllers.dropLast().last as? SixLetterTraceViewController,
           prevVC.currentLetterIndex == targetIndex,
           prevVC.contentType == self.contentType {
            nav.popViewController(animated: false)
        } else {
            let vc = storyboard!.instantiateViewController(withIdentifier: "SixLetterTraceVC") as! SixLetterTraceViewController
            vc.contentType = contentType
            vc.currentLetterIndex = targetIndex
            navigationController?.pushViewController(vc, animated: false)
        }
    }
    
    @IBAction func backTapped(_ sender: UIButton) { goBack() }
    @IBAction func homeTapped(_ sender: UIButton) { goHome() }

    // MARK: - Navigation Helpers
    func goHome() {
        navigationController?.popToRootViewController(animated: true)
    }

    func goBack() {
        guard let nav = navigationController else { return }
        for controller in nav.viewControllers {
            if String(describing: type(of: controller)).contains("WritingPreview") {
                nav.popToViewController(controller, animated: true)
                return
            }
        }
        nav.popViewController(animated: true)
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
    
    private func updateChevronStates() {
        let unlocked = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
        
        if currentIndex < unlocked {
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
            backChevronButton.isEnabled = (currentIndex > 0)
            backChevronButton.alpha = (currentIndex > 0) ? 1.0 : 0.4
            return
        }
        
        let hasSavedDrawing = (WritingGameplayManager.shared.loadOneDrawing(index: currentIndex, category: categoryKey) != nil)
        
        nextChevronButton.isEnabled = hasSavedDrawing
        nextChevronButton.alpha = hasSavedDrawing ? 1.0 : 0.4
        
        backChevronButton.isEnabled = (currentIndex > 0)
        backChevronButton.alpha = (currentIndex > 0) ? 1.0 : 0.4
    }
    
    // MARK: - CollectionView DataSource & Delegate
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch contentType {
        case .words: fatalError("Words not supported in OneLetterTraceViewController")
        case .letters: return 52
        case .numbers: return 10
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "alphabet_cell", for: indexPath)
        guard let button = cell.contentView.subviews.first as? UIButton else { return cell }
        
        let itemIndex = indexPath.item
        var titleString = ""
            if contentType == .letters {
                titleString = WritingGameplayManager.shared.getCharacterString(
                    for: itemIndex,
                    contentType: contentType
                )
            } else {
                titleString = "\(itemIndex)"
            }

        let unlockedIndex = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
        let isUnlocked = itemIndex <= unlockedIndex
        let isCompleted = itemIndex < unlockedIndex

        let backgroundColor: UIColor = isCompleted ? .systemGreen : (isUnlocked ? .systemBlue : .lightGray)
        let textColor: UIColor = isCompleted || isUnlocked ? .white : .darkGray

        cell.backgroundColor = backgroundColor

        var container = AttributeContainer()
        container.font = UIFont(name: "ArialRoundedMTBold", size: 30)
        container.foregroundColor = textColor
        
        var config = button.configuration ?? UIButton.Configuration.plain()
        config.attributedTitle = AttributedString(titleString, attributes: container)
        config.contentInsets = .zero
        button.configuration = config

        button.isEnabled = isUnlocked
        button.alpha = isUnlocked ? 1.0 : 0.6
        button.tag = itemIndex
        
        button.removeTarget(nil, action: nil, for: .allEvents)
        button.addTarget(self, action: #selector(letterButtonTapped(_:)), for: .touchUpInside)

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let idx = indexPath.item
        guard WritingGameplayManager.shared.isIndexUnlocked(index: idx, category: categoryKey) else { return }

        let vc = storyboard!.instantiateViewController(withIdentifier: "OneLetterTraceVC") as! OneLetterTraceViewController
        vc.contentType = contentType
        vc.currentLetterIndex = idx
        navigationController?.pushViewController(vc, animated: false)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 60, height: 60)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        cell.layoutIfNeeded()
        cell.layer.cornerRadius = cell.bounds.height / 2
        cell.clipsToBounds = true
    }
}
