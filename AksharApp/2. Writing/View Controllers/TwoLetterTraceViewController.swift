//
//  TwoLetterTraceViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit
import PencilKit
import AVFoundation

class TwoLetterTraceViewController: BaseTraceViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Properties
    
    // Helper to map 'currentLetterIndex' to Base Class 'currentIndex'
    var currentLetterIndex: Int {
        get { return currentIndex }
        set { currentIndex = newValue }
    }
    
    // MARK: - Outlets
    @IBOutlet weak var yellowView: UIView!
    @IBOutlet weak var speakerButton: UIView!
    @IBOutlet weak var alphabetCollectionView: UICollectionView!
    @IBOutlet weak var backChevronButton: UIButton!
    @IBOutlet weak var nextChevronButton: UIButton!
    @IBOutlet weak var traceCompleteButton: UIButton!
    @IBOutlet weak var retryButton: UIButton!
    
    // MARK: - Pane Views
    @IBOutlet weak var topLetterImageView: UIImageView!
    @IBOutlet weak var topCommittedDrawingImageView: UIImageView!
    @IBOutlet weak var topTransientDrawingImageView: UIImageView! // Unused, but kept for connection

    @IBOutlet weak var bottomLetterImageView: UIImageView!
    @IBOutlet weak var bottomCommittedDrawingImageView: UIImageView!
    @IBOutlet weak var bottomTransientDrawingImageView: UIImageView! // Unused, but kept for connection
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. Initialize Base Class logic for 2 Panes
        initPaneArrays(count: 2)
        
        // 2. Register UI components with Base Class
        // Index 0 = Top, Index 1 = Bottom
        paneLetterImageViews = [topLetterImageView, bottomLetterImageView]
        
        // 3. Setup Tracing Layers via Base Helpers
        setupShapeLayer(for: topLetterImageView)
        setupShapeLayer(for: bottomLetterImageView)
        
        let topCanvas = setupCanvas(in: topCommittedDrawingImageView)
        let bottomCanvas = setupCanvas(in: bottomCommittedDrawingImageView)
        paneCommittedCanvases = [topCanvas, bottomCanvas]
        
        // 4. Standard UI Setup
        setupUIAppearance()
        setupCollectionView()
        
        // 5. Load Content
        showLetter(at: currentIndex)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNextChevronState()
        alphabetCollectionView.reloadData()
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
        let brownColor = UIColor(red: 135/255.0, green: 87/255.0, blue: 55/255.0, alpha: 1.0).cgColor
        let yellowColor = UIColor(red: 248/255.0, green: 236/255.0, blue: 180/255.0, alpha: 1.0).cgColor
        
        func style(_ view: UIView, border: CGColor, width: CGFloat = 3) {
            view.layer.borderColor = border
            view.layer.borderWidth = width
        }
        
        style(speakerButton, border: brownColor)
        style(retryButton, border: brownColor)
        style(traceCompleteButton, border: brownColor)
        style(alphabetCollectionView, border: yellowColor)
        alphabetCollectionView.layer.borderWidth = 2
        alphabetCollectionView.layer.cornerRadius = 20
        
        yellowView.layer.cornerRadius = 25
        retryButton.isHidden = false
        
        nextChevronButton.isEnabled = false
        nextChevronButton.alpha = 0.4
        speakerButton.isUserInteractionEnabled = true
        
        // Base class handles interaction
        topLetterImageView.isUserInteractionEnabled = false
        bottomLetterImageView.isUserInteractionEnabled = false
        topCommittedDrawingImageView.isUserInteractionEnabled = false
        bottomCommittedDrawingImageView.isUserInteractionEnabled = false
    }

    // MARK: - Content Loading
    private func showLetter(at index: Int) {
        currentIndex = index
        let category = categoryKey
        
        // MVC: Load Mistakes
        mistakeCount = WritingGameplayManager.shared.getMistakeCount(index: currentIndex, category: category)
        
        // Load UI Images
        var letterAssetName = ""
        switch contentType {
        case .letters:
            letterAssetName = String(UnicodeScalar(65 + index)!)
            let img = UIImage(named: "letter_\(letterAssetName)") ?? UIImage(named: letterAssetName)
            topLetterImageView.image = img
            bottomLetterImageView.image = img
            paneMaskAssetNames = ["\(letterAssetName)_mask"]
        case .numbers:
            letterAssetName = "number_\(index)"
            let img = UIImage(named: letterAssetName)
            topLetterImageView.image = img
            bottomLetterImageView.image = img
            paneMaskAssetNames = ["\(index)_mask"]
        }
        
        // Base Class: Load Masks for BOTH panes
        loadMasks(forPane: 0, assetNames: paneMaskAssetNames)
        loadMasks(forPane: 1, assetNames: paneMaskAssetNames)
        
        // MVC: Load Drawings (Tuple)
        if let (top, bottom) = WritingGameplayManager.shared.loadTwoDrawings(index: currentIndex, category: category) {
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
            
            isTracingLocked = false // Allow user to finish the other one
        } else {
            paneCommittedCanvases[0].drawing = PKDrawing()
            paneCommittedCanvases[1].drawing = PKDrawing()
            paneIsCompleted = [false, false]
            paneCurrentMaskIndex = [0, 0]
            isTracingLocked = false
        }
        
        resetTransientLayer(paneIndex: 0)
        resetTransientLayer(paneIndex: 1)
        alphabetCollectionView.reloadData()
        updateNextChevronState()
    }
    
    private func onAllStrokesCompleted() {
        // MVC: Save Both
        WritingGameplayManager.shared.saveTwoDrawings(
            top: paneCommittedCanvases[0].drawing,
            bottom: paneCommittedCanvases[1].drawing,
            index: currentIndex,
            category: categoryKey
        )
        
        alphabetCollectionView.reloadData()
        nextChevronButton.isEnabled = true
        nextChevronButton.alpha = 1.0
        
        // Analytics
        let penalty = mistakeCount * 10
        let performanceScore = max(0, 100 - penalty)
        
        let session = WritingSessionData(
            id: UUID(),
            date: Date(),
            childId: "default_child",
            lettersAccuracy: contentType == .letters ? performanceScore : 0,
            wordsAccuracy: 0,
            numbersAccuracy: contentType == .numbers ? performanceScore : 0
        )
        AnalyticsStore.shared.appendWritingSession(session)
        
        // Reset Mistakes
        WritingGameplayManager.shared.saveMistakeCount(0, index: currentIndex, category: categoryKey)
    }

    // MARK: - Actions
    @IBAction func traceCompleteTapped(_ sender: Any) {
        // Check for Red Error State (handled visually by Base via ShapeLayer color)
        if paneShapeLayers[0].strokeColor == UIColor.red.cgColor ||
           paneShapeLayers[1].strokeColor == UIColor.red.cgColor {
            return
        }
        
        var didAdvanceTop = false
        var didAdvanceBottom = false
        
        // Process Top Pane
        if !paneIsCompleted[0] {
            didAdvanceTop = checkAndCommitGreenInk(paneIndex: 0)
        }
        
        // Process Bottom Pane
        if !paneIsCompleted[1] {
            didAdvanceBottom = checkAndCommitGreenInk(paneIndex: 1)
        }
        
        // Check Completion
        if paneIsCompleted[0] && paneIsCompleted[1] {
            onAllStrokesCompleted()
            
            let penalty = mistakeCount * 10
            let accuracy = max(0, 100 - penalty)
            if accuracy >= 80 {
                showStickerFromBottom(assetName: "sticker")
            }
        } else if !didAdvanceTop && !didAdvanceBottom {
            // Neither pane made progress
            flashIncompleteWarning()
        }
        
        // Clear transient lines if completed
        if paneIsCompleted[0] { resetTransientLayer(paneIndex: 0) }
        if paneIsCompleted[1] { resetTransientLayer(paneIndex: 1) }
    }
    
    @IBAction func retryTapped(_ sender: UIButton) {
        let topCompleted = paneIsCompleted[0]
        let bottomCompleted = paneIsCompleted[1]
        
        // Smart Retry Logic: Only clear the incomplete pane
        switch (topCompleted, bottomCompleted) {
        case (true, false):
            // Top is done, reset Bottom only
            resetPane(1)
            
        case (false, true):
            // Bottom is done, reset Top only
            resetPane(0)
            
        case (true, true), (false, false):
            // Both done or both empty -> Full Reset
            resetPane(0)
            resetPane(1)
        }
        
        isTracingLocked = false
    }
    
    private func resetPane(_ index: Int) {
        resetTransientLayer(paneIndex: index)
        paneCommittedCanvases[index].drawing = PKDrawing()
        paneIsCompleted[index] = false
        paneCurrentMaskIndex[index] = 0
    }
    
    @IBAction func backTapped(_ sender: UIButton) { goBack() }
    @IBAction func homeTapped(_ sender: UIButton) { goHome() }
    
    @IBAction func nextChevronTapped(_ sender: Any) {
        let vc = storyboard!.instantiateViewController(withIdentifier: "SixLetterTraceVC") as! SixLetterTraceViewController
        vc.contentType = contentType
        vc.currentLetterIndex = currentIndex
        navigationController?.pushViewController(vc, animated: false)
    }
    
    @IBAction func previousChevronTapped(_ sender: UIButton) {
        let targetIndex = currentIndex
        if let nav = navigationController,
           let prevVC = nav.viewControllers.dropLast().last as? OneLetterTraceViewController,
           prevVC.currentLetterIndex == targetIndex, prevVC.contentType == self.contentType {
            nav.popViewController(animated: false)
        } else {
            let vc = storyboard!.instantiateViewController(withIdentifier: "OneLetterTraceVC") as! OneLetterTraceViewController
            vc.contentType = contentType
            vc.currentIndex = targetIndex
            navigationController?.pushViewController(vc, animated: false)
        }
    }
    
    @IBAction func speakerButtonTapped(_ sender: UIButton) {
        let textToSpeak = (contentType == .letters) ? String(UnicodeScalar(65 + currentIndex)!) : "\(currentIndex)"
        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
    
    @IBAction func letterButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        let unlocked = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
        
        guard index <= unlocked else { return }
        
        let vc = storyboard!.instantiateViewController(withIdentifier: "OneLetterTraceVC") as! OneLetterTraceViewController
        vc.contentType = contentType
        vc.currentIndex = index
        navigationController?.pushViewController(vc, animated: false)
    }

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
    
    private func updateNextChevronState() {
        let unlocked = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
        
        // 1. History Check
        if currentIndex < unlocked {
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
            return
        }
        
        // 2. Current Check
        if let (top, bottom) = WritingGameplayManager.shared.loadTwoDrawings(index: currentIndex, category: categoryKey) {
             let isComplete = !top.strokes.isEmpty && !bottom.strokes.isEmpty
             nextChevronButton.isEnabled = isComplete
             nextChevronButton.alpha = isComplete ? 1.0 : 0.4
        } else {
             nextChevronButton.isEnabled = false
             nextChevronButton.alpha = 0.4
        }
    }

    // MARK: - CollectionView DataSource & Delegate
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch contentType {
        case .letters: return 26
        case .numbers: return 10
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "alphabet_cell", for: indexPath)
        guard let button = cell.contentView.subviews.first as? UIButton else { return cell }
        
        let itemIndex = indexPath.item
        let titleString = (contentType == .letters) ? String(UnicodeScalar(65 + itemIndex)!) : "\(itemIndex)"
        
        // MVC: Check Status
        let unlockedIndex = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
        let isUnlocked = itemIndex <= unlockedIndex
        let isCompleted = itemIndex < unlockedIndex
        
        cell.backgroundColor = isCompleted ? .systemGreen : (isUnlocked ? .systemBlue : .lightGray)
        let textColor: UIColor = (isCompleted || isUnlocked) ? .white : .darkGray
        
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
        let unlocked = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
        
        guard idx <= unlocked else { return }
        
        let vc = storyboard!.instantiateViewController(withIdentifier: "OneLetterTraceVC") as! OneLetterTraceViewController
        vc.contentType = contentType
        vc.currentIndex = idx
        navigationController?.pushViewController(vc, animated: false)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 60, height: 60)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) -> UIImageView {
        cell.layoutIfNeeded()
        cell.layer.cornerRadius = cell.bounds.height / 2
        cell.clipsToBounds = true
        return UIImageView() // Just to satisfy return type if needed, or void
    }
}
