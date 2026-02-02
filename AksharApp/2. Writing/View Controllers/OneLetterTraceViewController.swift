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
    
    // Links 'currentLetterIndex' to the Base Class 'currentIndex' to fix "Cannot find currentLetterIndex" errors
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

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. Initialize Base Class logic for 1 Pane
        initPaneArrays(count: 1)
        
        // 2. Register UI components with Base Class
        paneLetterImageViews = [letterImageView]
        
        // 3. Setup Tracing Layers via Base Helpers
        setupShapeLayer(for: letterImageView)
        
        // This adds the canvas to the view automatically
        let canvas = setupCanvas(in: committedDrawingImageView)
        paneCommittedCanvases = [canvas]
        
        // 4. Standard UI Setup
        setupUIAppearance()
        setupCollectionView()
        
        // 5. Load Content
        showLetter(at: currentIndex)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateChevronStates()
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
        
        func style(_ view: UIView, border: CGColor, width: CGFloat = 3, radius: CGFloat? = nil) {
            view.layer.borderColor = border
            view.layer.borderWidth = width
            if let r = radius { view.layer.cornerRadius = r }
        }
        
        style(speakerButton, border: brownColor)
        style(retryButton, border: brownColor)
        style(tickButton, border: brownColor)
        style(alphabetCollectionView, border: yellowColor, width: 2, radius: 20)
        
        yellowView.layer.cornerRadius = 25
        retryButton.isHidden = false
        
        nextChevronButton.isEnabled = false
        nextChevronButton.alpha = 0.4
        
        // UI Cleanup (Base class handles touches, so we disable interaction on images)
        letterImageView.isUserInteractionEnabled = false
        letterImageView.contentMode = .scaleAspectFit
        committedDrawingImageView.isUserInteractionEnabled = false
        committedDrawingImageView.backgroundColor = .clear
        
        // Setup speaker tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(speakerButtonTapped))
        speakerButton.addGestureRecognizer(tap)
        speakerButton.isUserInteractionEnabled = true
    }

    // MARK: - Content Loading
    private func showLetter(at index: Int) {
        currentIndex = index
        let category = categoryKey // Property from BaseTraceViewController
        
        // MVC: Load Mistakes (mistakeCount is inherited from BaseTraceViewController)
        mistakeCount = WritingGameplayManager.shared.getMistakeCount(index: currentIndex, category: category)
        
        // Load UI Images & Set Mask Names
        var letterAssetName = ""
        switch contentType {
        case .letters:
            letterAssetName = String(UnicodeScalar(65 + index)!)
            letterImageView.image = UIImage(named: "letter_\(letterAssetName)") ?? UIImage(named: letterAssetName)
            // Fixes "Cannot find paneMaskAssetNames"
            paneMaskAssetNames = ["\(letterAssetName)_mask"]
        case .numbers:
            letterAssetName = "number_\(index)"
            letterImageView.image = UIImage(named: letterAssetName)
            paneMaskAssetNames = ["\(index)_mask"]
        }
        
        // Base Class: Load Masks automatically
        loadMasks(forPane: 0, assetNames: paneMaskAssetNames)
        
        // MVC: Load Drawing
        if let savedDrawing = WritingGameplayManager.shared.loadOneDrawing(index: index, category: category) {
            paneCommittedCanvases[0].drawing = savedDrawing
            let hasContent = !savedDrawing.strokes.isEmpty
            
            // Logic: Is this letter historically done?
            let maxUnlocked = WritingGameplayManager.shared.getHighestUnlockedIndex(category: category)
            let isHistoricallyDone = (index < maxUnlocked)
            
            // Use Base properties: paneIsCompleted, paneCurrentMaskIndex, isTracingLocked
            if (isHistoricallyDone && hasContent) || hasContent {
                paneIsCompleted[0] = true
                paneCurrentMaskIndex[0] = 999 // Force Complete
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
        
        // MVC: Save Drawing
        WritingGameplayManager.shared.saveOneDrawing(
            paneCommittedCanvases[0].drawing,
            index: currentIndex,
            category: categoryKey
        )
        
        nextChevronButton.isEnabled = true
        nextChevronButton.alpha = 1.0
        view.bringSubviewToFront(nextChevronButton)
        
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
        // If locked (completed), don't do anything unless we are just re-checking
        if isTracingLocked && !paneIsCompleted[0] { return }

        // Base Class Logic: Check if the white stroke covers enough of the mask
        // If yes, it turns it green and returns true.
        let didAdvance = checkAndCommitGreenInk(paneIndex: 0)

        if paneIsCompleted[0] {
            onAllStrokesCompleted()
            
            // Optional: Sticker Logic
            let penalty = mistakeCount * 10
            let accuracy = max(0, 100 - penalty)
            if accuracy >= 80 {
                showStickerFromBottom(assetName: "sticker")
            }
        } else if !didAdvance {
            // Local UI: Flash the button if the user clicked it too early
            flashIncompleteWarning()
        }
    }
    
    @IBAction func retryTapped(_ sender: UIButton) {
        // Clear UI only, keep file on disk
        isTracingLocked = false
        paneIsCompleted[0] = false
        paneCurrentMaskIndex[0] = 0

        // Base Class: Helper to clear the white lines
        resetTransientLayer(paneIndex: 0)
        paneCommittedCanvases[0].drawing = PKDrawing()
        
        // No need to update chevrons because the file remains on disk
    }
    
    @objc @IBAction func speakerButtonTapped(_ sender: Any) {
        let textToSpeak: String
        switch contentType {
        case .letters:
            textToSpeak = String(UnicodeScalar(65 + currentLetterIndex)!)
        case .numbers:
            textToSpeak = "\(currentLetterIndex)"
        }
        
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
        
        // 1. History Check
        if currentIndex < unlocked {
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
            backChevronButton.isEnabled = (currentIndex > 0)
            backChevronButton.alpha = (currentIndex > 0) ? 1.0 : 0.4
            return
        }
        
        // 2. Current Check: strict file check
        let hasSavedDrawing = (WritingGameplayManager.shared.loadOneDrawing(index: currentIndex, category: categoryKey) != nil)
        
        nextChevronButton.isEnabled = hasSavedDrawing
        nextChevronButton.alpha = hasSavedDrawing ? 1.0 : 0.4
        
        backChevronButton.isEnabled = (currentIndex > 0)
        backChevronButton.alpha = (currentIndex > 0) ? 1.0 : 0.4
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
        let unlocked = WritingGameplayManager.shared.getHighestUnlockedIndex(category: categoryKey)
        guard idx <= unlocked else { return }

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
