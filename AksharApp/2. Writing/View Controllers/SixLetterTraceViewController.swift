//
//  SixLetterTraceViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit
import PencilKit
import AVFoundation

class SixLetterTraceViewController: BaseTraceViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Properties
    
    // Helper to map 'currentLetterIndex' to Base Class 'currentIndex'
    var currentLetterIndex: Int {
        get { return currentIndex }
        set { currentIndex = newValue }
    }
    
    private var analyticsSessionID: UUID!
    
    // MARK: - Outlets: General
    @IBOutlet weak var yellowView: UIView!
    @IBOutlet weak var speakerButton: UIView!
    @IBOutlet weak var alphabetCollectionView: UICollectionView!
    @IBOutlet weak var traceCompleteButton: UIButton!
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var backChevronButton: UIButton!
    @IBOutlet weak var nextChevronButton: UIButton!
    
    // MARK: - Outlets: Panes (1-6)
    @IBOutlet weak var pane1LetterImageView: UIImageView!
    @IBOutlet weak var pane1CommittedDrawingImageView: UIImageView!
    @IBOutlet weak var pane1TransientDrawingImageView: UIImageView! // Unused

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
        
        analyticsSessionID = UUID()
        
        // 1. Initialize Base Class logic for 6 Panes
        initPaneArrays(count: 6)
        
        // 2. Register UI components with Base Class (Order Matters!)
        paneLetterImageViews = [
            pane1LetterImageView, pane2LetterImageView, pane3LetterImageView,
            pane4LetterImageView, pane5LetterImageView, pane6LetterImageView
        ]
        
        let committedImageViews = [
            pane1CommittedDrawingImageView, pane2CommittedDrawingImageView, pane3CommittedDrawingImageView,
            pane4CommittedDrawingImageView, pane5CommittedDrawingImageView, pane6CommittedDrawingImageView
        ]
        
        // 3. Setup Tracing Layers & Canvases via Loop
        for i in 0..<6 {
            setupShapeLayer(for: paneLetterImageViews[i])
            let canvas = setupCanvas(in: committedImageViews[i]!)
            paneCommittedCanvases.append(canvas)
        }
        
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
        for iv in paneLetterImageViews { iv.isUserInteractionEnabled = false }
    }

    // MARK: - Content Loading
    private func showLetter(at index: Int) {
        currentIndex = index
        let category = categoryKey
        
        // MVC: Load Mistakes
        mistakeCount = WritingGameplayManager.shared.getMistakeCount(index: currentIndex, category: category)
        
        var boxAssetBaseName = ""
        var maskNameList: [String] = []

        // 1. Setup Images & Asset Names
        switch contentType {
        case .letters:
            let letterChar = String(UnicodeScalar(65 + index)!)
            boxAssetBaseName = "box_\(letterChar.lowercased())"
            
            let letterImg = UIImage(named: "letter_\(letterChar)") ?? UIImage(named: letterChar)
            
            // Set 1-4 to standard letter
            for i in 0...3 { paneLetterImageViews[i].image = letterImg }
            
            // Set 5-6 to Box version if available
            if let boxImg = UIImage(named: boxAssetBaseName) {
                paneLetterImageViews[4].image = boxImg; paneLetterImageViews[5].image = boxImg
            } else {
                paneLetterImageViews[4].image = letterImg; paneLetterImageViews[5].image = letterImg
            }
            maskNameList = ["\(letterChar)_mask"]

        case .numbers:
            let numberImg = UIImage(named: "number_\(index)")
            boxAssetBaseName = "box_\(index)"
            
            for i in 0...3 { paneLetterImageViews[i].image = numberImg }
            
            if let boxImg = UIImage(named: boxAssetBaseName) {
                paneLetterImageViews[4].image = boxImg; paneLetterImageViews[5].image = boxImg
            } else {
                paneLetterImageViews[4].image = numberImg; paneLetterImageViews[5].image = numberImg
            }
            maskNameList = ["\(index)_mask"]
        }
        
        // 2. Load Masks for ALL 6 Panes
        for i in 0..<6 {
            loadMasks(forPane: i, assetNames: maskNameList)
        }
        
        // 3. MVC: Load Drawings (Array of 6)
        if let savedDrawings = WritingGameplayManager.shared.loadSixDrawings(index: currentIndex, category: category),
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
            isTracingLocked = false
        } else {
            // Reset
            for i in 0..<6 {
                paneCommittedCanvases[i].drawing = PKDrawing()
                paneIsCompleted[i] = false
                paneCurrentMaskIndex[i] = 0
            }
            isTracingLocked = false
        }
        
        // Reset Transient UI
        for i in 0..<6 { resetTransientLayer(paneIndex: i) }
        
        alphabetCollectionView.reloadData()
        updateNextChevronState()
    }
    
    private func onAllStrokesCompleted() {
        let drawings = paneCommittedCanvases.map { $0.drawing }
        
        // MVC: Save 6 Drawings
        WritingGameplayManager.shared.saveSixDrawings(drawings, index: currentIndex, category: categoryKey)
        
        // MVC: Unlock Next Letter (Index + 1)
        WritingGameplayManager.shared.unlockNextItem(category: categoryKey, currentIndex: currentIndex)
        
        alphabetCollectionView.reloadData()
        nextChevronButton.isEnabled = true
        nextChevronButton.alpha = 1.0
        
        // Analytics
        let penalty = mistakeCount * 10
        let performanceScore = max(0, 100 - penalty)
        
        let session = WritingSessionData(
            id: analyticsSessionID,
            date: Date(),
            childId: "default_child",
            lettersAccuracy: contentType == .letters ? performanceScore : 0,
            wordsAccuracy: 0,
            numbersAccuracy: contentType == .numbers ? performanceScore : 0
        )
        AnalyticsStore.shared.appendWritingSession(session)
        
        // Reset Mistakes
        WritingGameplayManager.shared.saveMistakeCount(0, index: currentIndex, category: categoryKey)
        isTracingLocked = true
    }

    // MARK: - Actions
    @IBAction func traceCompleteTapped(_ sender: Any) {
        // Check for Red Error State
        for i in 0..<6 {
            if paneShapeLayers[i].strokeColor == UIColor.red.cgColor { return }
        }
        
        var didAdvanceAny = false
        
        // Iterate through all 6 panes
        for i in 0..<6 {
            if !paneIsCompleted[i] {
                let advanced = checkAndCommitGreenInk(paneIndex: i)
                if advanced { didAdvanceAny = true }
            }
        }
        
        // Check Full Completion
        let fullyComplete = paneIsCompleted.allSatisfy { $0 == true }
        
        if fullyComplete {
            onAllStrokesCompleted()
            let penalty = mistakeCount * 10
            let accuracy = max(0, 100 - penalty)
            if accuracy >= 80 {
                showStickerFromBottom(assetName: "sticker")
            }
        } else if !didAdvanceAny {
            flashIncompleteWarning()
        }
    }
    
    @IBAction func retryTapped(_ sender: UIButton) {
        let completedCount = paneIsCompleted.filter { $0 }.count

        if completedCount > 0 && completedCount < 6 {
            // Partial: Clear onscreen ONLY for non-completed panes
            for i in 0..<6 where !paneIsCompleted[i] {
                resetPane(i)
            }
        } else {
            // Full Reset: Clear UI ONLY. Do NOT delete files.
            for i in 0..<6 {
                resetPane(i)
            }
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
        let vc = storyboard!.instantiateViewController(withIdentifier: "OneLetterTraceVC") as! OneLetterTraceViewController
        vc.contentType = contentType
        vc.currentLetterIndex = currentIndex + 1
        navigationController?.pushViewController(vc, animated: false)
    }
    
    // FIX: Renamed from previousChevronTapped to previousChevrontapped (lowercase 't') to match Storyboard
    @IBAction func previousChevrontapped(_ sender: UIButton) {
        let targetIndex = currentIndex
        if let nav = navigationController,
           let prevVC = nav.viewControllers.dropLast().last as? TwoLetterTraceViewController,
           prevVC.currentLetterIndex == targetIndex,
           prevVC.contentType == self.contentType {
            nav.popViewController(animated: false)
        } else {
            let vc = storyboard!.instantiateViewController(withIdentifier: "TwoLetterTraceVC") as! TwoLetterTraceViewController
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
        if let drawings = WritingGameplayManager.shared.loadSixDrawings(index: currentIndex, category: categoryKey) {
             let isComplete = drawings.allSatisfy { !$0.strokes.isEmpty }
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
        return UIImageView()
    }
}
