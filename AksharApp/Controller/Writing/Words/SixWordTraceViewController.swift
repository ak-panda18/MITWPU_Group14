//
//  SixWordTraceViewController.swift
//  AksharApp
//
//  Created by AksharApp on 14/01/26.
//

import UIKit
import PencilKit
import AVFoundation

class SixWordTraceViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Data Model
    var selectedCategory: TracingCategory = .threeLetter
    var currentWordIndex: Int = 0
    private var mistakeCount = 0
    private var words: [TracingWord] = []
    private var maskAssetNames: [String] = []
    private var analyticsSessionID: UUID!

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
    
    // MARK: - Pane Collections
    private var letterImageViews: [UIImageView] = []
    private var committedImageViews: [UIImageView] = []
    private var transientImageViews: [UIImageView] = []
    private var committedCanvasViews: [PKCanvasView] = []
    
    // MARK: - Pane State (Tracing)
    private var paneShapeLayers: [CAShapeLayer] = []
    private var panePaths: [UIBezierPath] = []
    private var paneStrokeSegments: [[[CGPoint]]] = Array(repeating: [], count: 6)
    private var paneCurrentStrokePoints: [[CGPoint]] = Array(repeating: [], count: 6)
    private var paneTransientTouchedPixels: [Set<Int>] = Array(repeating: Set<Int>(), count: 6)
    private var paneCurrentStrokeIndex: [Int] = Array(repeating: 0, count: 6)
    private var paneCompleted: [Bool] = Array(repeating: false, count: 6)
    
    // MARK: - Mask Data
    private var sharedMaskDataArrays: [[UInt8]] = []
    private var sharedMaskSizes: [CGSize] = []
    private var sharedMaskOpaqueCounts: [Int] = []
    
    // MARK: - Configuration
    private var activePaneIndex: Int? = nil
    private var isTracingLocked = false
    private let synthesizer = AVSpeechSynthesizer()
    private var didSetupAfterLayout = false
    private var isWordCompleted: Bool = false
    private let coverageThreshold: CGFloat = 0.70
    private let alphaThreshold: UInt8 = 12
    private let deviationResetDelay: TimeInterval = 0.5
    private var brushWidth: CGFloat {
            switch selectedCategory {
            case .threeLetter:
                return 22.0
            case .fourLetter:
                return 20.0
            case .fiveLetter:
                return 15.0
            case .sixLetter:
                return 12.0
            default:
                return 20.0
            }
        }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupArrays()
        setupUI()
        setupTracingViews()
        setupPencilKitCanvases()
        TracingProgressManager.shared.setActiveWord(
            index: currentWordIndex,
            category: selectedCategory.rawValue
        )
        
        if let savedID = TracingProgressManager.shared.getSessionID(index: currentWordIndex, category: selectedCategory.rawValue) {
                    analyticsSessionID = savedID
                } else {
                    analyticsSessionID = UUID()
                    TracingProgressManager.shared.saveSessionID(analyticsSessionID, index: currentWordIndex, category: selectedCategory.rawValue)
                }
        
        let allWords = TracingWordLoader.loadWords()
        words = allWords.words(for: selectedCategory.rawValue)
        wordsCollectionView.reloadData()
        
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
        if !didSetupAfterLayout {
            loadMasksForAllPanes()
            alignLayers()
            didSetupAfterLayout = true
        }
        view.bringSubviewToFront(nextChevronButton)
        view.bringSubviewToFront(backChevronButton)
        view.bringSubviewToFront(retryButton)
        view.bringSubviewToFront(traceCompleteButton)
    }
    
    // MARK: - Setup Methods
    private func calculateFullPageAccuracy(
        touched: Int,
        total: Int
    ) -> CGFloat {
        guard total > 0 else { return 0 }
        return (CGFloat(touched) / CGFloat(total)) * 100
    }

    private func setupArrays() {
        letterImageViews = [
            pane1LetterImageView, pane2LetterImageView, pane3LetterImageView,
            pane4LetterImageView, pane5LetterImageView, pane6LetterImageView
        ]
        committedImageViews = [
            pane1CommittedDrawingImageView, pane2CommittedDrawingImageView, pane3CommittedDrawingImageView,
            pane4CommittedDrawingImageView, pane5CommittedDrawingImageView, pane6CommittedDrawingImageView
        ]
        transientImageViews = [
            pane1TransientDrawingImageView, pane2TransientDrawingImageView, pane3TransientDrawingImageView,
            pane4TransientDrawingImageView, pane5TransientDrawingImageView, pane6TransientDrawingImageView
        ]
        
        for _ in 0..<6 {
            panePaths.append(UIBezierPath())
            paneShapeLayers.append(CAShapeLayer())
        }
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
    }
    
    private func setupTracingViews() {
        for i in 0..<6 {
            let letterIV = letterImageViews[i]
            let shapeLayer = paneShapeLayers[i]
            shapeLayer.strokeColor = UIColor.white.cgColor
            shapeLayer.lineWidth = brushWidth
            shapeLayer.lineCap = .round
            shapeLayer.lineJoin = .round
            shapeLayer.fillColor = UIColor.clear.cgColor
            letterIV.layer.addSublayer(shapeLayer)
            letterIV.frame = letterIV.bounds
        }
    }
    
    private func setupPencilKitCanvases() {
        committedCanvasViews.removeAll()
        for i in 0..<6 {
            let container = committedImageViews[i]
            let canvas = PKCanvasView(frame: .zero)
            canvas.backgroundColor = .clear
            canvas.isOpaque = false
            canvas.drawing = PKDrawing()
            canvas.tool = PKInkingTool(.pen, color: UIColor.systemGreen, width: brushWidth)
            canvas.isUserInteractionEnabled = false
            canvas.translatesAutoresizingMaskIntoConstraints = false
            
            container.addSubview(canvas)
            committedCanvasViews.append(canvas)
            
            NSLayoutConstraint.activate([
                canvas.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                canvas.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                canvas.topAnchor.constraint(equalTo: container.topAnchor),
                canvas.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
    }
    
    private func alignLayers() {
        for i in 0..<6 {
            paneShapeLayers[i].frame = letterImageViews[i].bounds
            committedCanvasViews[i].setNeedsDisplay()
        }
    }

    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isTracingLocked { return }
        guard let touch = touches.first else { return }
        
        activePaneIndex = nil
        for i in 0..<6 {
            let loc = touch.location(in: letterImageViews[i])
            if paneCompleted[i] { continue }
            if letterImageViews[i].bounds.contains(loc) {
                activePaneIndex = i
                panePaths[i].move(to: loc)
                paneCurrentStrokePoints[i] = [loc]
                break
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isTracingLocked { return }
        guard let idx = activePaneIndex, let touch = touches.first, let event = event else { return }
        guard !paneCompleted[idx] else { return }
        if let coalesced = event.coalescedTouches(for: touch) {
            for cTouch in coalesced {
                if isTracingLocked { break }
                let loc = cTouch.location(in: letterImageViews[idx])
                panePaths[idx].addLine(to: loc)
                paneCurrentStrokePoints[idx].append(loc)
                validatePoint(loc, paneIndex: idx)
            }
        }
        paneShapeLayers[idx].path = panePaths[idx].cgPath
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let idx = activePaneIndex else { return }
        if !paneCurrentStrokePoints[idx].isEmpty {
            paneStrokeSegments[idx].append(paneCurrentStrokePoints[idx])
            paneCurrentStrokePoints[idx] = []
        }
        activePaneIndex = nil
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let idx = activePaneIndex {
            resetTransientLayer(paneIndex: idx)
        }
        activePaneIndex = nil
    }

    // MARK: - Validation Logic
    private func validatePoint(_ point: CGPoint, paneIndex: Int) {
        if isTracingLocked { return }
        let strokeIdx = paneCurrentStrokeIndex[paneIndex]
        guard strokeIdx < sharedMaskSizes.count else { return }

        let maskSize = sharedMaskSizes[strokeIdx]
        let imageView = letterImageViews[paneIndex]
        
        let scale = min(imageView.bounds.width / maskSize.width, imageView.bounds.height / maskSize.height)
        let xOffset = (imageView.bounds.width - maskSize.width * scale) / 2
        let yOffset = (imageView.bounds.height - maskSize.height * scale) / 2

        let px = (point.x - xOffset) / scale
        let py = (point.y - yOffset) / scale
        
        guard px >= 0, py >= 0, px < maskSize.width, py < maskSize.height else {
            triggerDeviation(paneIndex: paneIndex)
            return
        }

        let imagePoint = CGPoint(x: px, y: py)
        let maskData = sharedMaskDataArrays[strokeIdx]

        if isMaskPixelOpaque(maskData: maskData, maskSize: maskSize, atImagePoint: imagePoint) {
            paneShapeLayers[paneIndex].strokeColor = UIColor.white.cgColor
            
            let w = Int(maskSize.width)
            let h = Int(maskSize.height)
            let centerX = Int(px)
            let centerY = Int(py)
            let brushRadius = Int(brushWidth / scale)

            for dy in -brushRadius...brushRadius {
                for dx in -brushRadius...brushRadius {
                    let x = centerX + dx
                    let y = centerY + dy
                    if x < 0 || y < 0 || x >= w || y >= h { continue }
                    if dx*dx + dy*dy > brushRadius*brushRadius { continue }
                    
                    let pixelIndex = y * w + x
                    paneTransientTouchedPixels[paneIndex].insert(pixelIndex)
                }
            }
        } else {
            triggerDeviation(paneIndex: paneIndex)
        }
    }
    
    private func isMaskPixelOpaque(maskData: [UInt8], maskSize: CGSize, atImagePoint point: CGPoint) -> Bool {
        let width = Int(maskSize.width)
        let height = Int(maskSize.height)
        let x = Int(point.x)
        let y = Int(point.y)
        
        if x < 0 || x >= width || y < 0 || y >= height { return false }
        let pixelIndex = (y * width + x) * 4
        if pixelIndex + 3 >= maskData.count { return false }
        
        return maskData[pixelIndex + 3] > alphaThreshold
    }
    
    private func triggerDeviation(paneIndex: Int) {
        if isTracingLocked { return }
        mistakeCount += 1
        TracingProgressManager.shared.saveMistakeCount(mistakeCount, index: currentWordIndex, category: selectedCategory.rawValue)
        hardLockTracing()
        paneShapeLayers[paneIndex].strokeColor = UIColor.red.cgColor
        
        DispatchQueue.main.asyncAfter(deadline: .now() + deviationResetDelay) {
            self.resetTransientLayer(paneIndex: paneIndex)
            self.isTracingLocked = false
            self.setCanvasInteraction(true)
        }
    }

    // MARK: - Word Loading
    private func loadWord(at index: Int) {
        guard index < words.count else { return }
        mistakeCount = TracingProgressManager.shared.getMistakeCount(index: index, category: selectedCategory.rawValue)
        currentWordIndex = index
        let word = words[index]
        
        if let image = UIImage(named: word.wordImageName) {
            for iv in letterImageViews { iv.image = image; iv.tintColor = nil }
        }
        
        maskAssetNames = ["\(word.wordImageName)_mask"]
        if let savedDrawings = TracingProgressManager.shared.loadSixWordDrawings(index: index, category: selectedCategory.rawValue) {
            for i in 0..<6 {
                committedCanvasViews[i].drawing = savedDrawings[i]
            }

            let unlockedIdx = TracingProgressManager.shared.highestUnlockedWordIndex(for: selectedCategory.rawValue)
            let isHistoricallyDone = index < unlockedIdx
            
            var allPanesVisuallyComplete = true
            for i in 0..<6 {
                let hasContent = !savedDrawings[i].strokes.isEmpty
                
                if isHistoricallyDone {
                    paneCompleted[i] = hasContent
                    if !hasContent {
                        allPanesVisuallyComplete = false
                    }
                } else {
                    paneCompleted[i] = false
                    allPanesVisuallyComplete = false
                    if hasContent {
                        paneCurrentStrokeIndex[i] = 0
                    }
                }
            }
            isTracingLocked = allPanesVisuallyComplete
            isWordCompleted = allPanesVisuallyComplete
            
            setCanvasInteraction(!isTracingLocked)

            if isTracingLocked {
                traceCompleteButton.backgroundColor = .systemGreen
            } else {
                traceCompleteButton.backgroundColor = .white
            }
            
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0

        } else {
            resetFullTrace()
            traceCompleteButton.backgroundColor = .white
            nextChevronButton.isEnabled = false
            nextChevronButton.alpha = 0.4
        }
        
        if didSetupAfterLayout { loadMasksForAllPanes() }
        wordsCollectionView.reloadData()
        updateNextChevronState()
    }
    
    private func loadMasksForAllPanes() {
        sharedMaskDataArrays.removeAll()
        sharedMaskSizes.removeAll()
        sharedMaskOpaqueCounts.removeAll()

        for name in maskAssetNames {
            if let image = UIImage(named: name),
               let (bytes, size) = getNormalizedRGBAData(from: image) {

                sharedMaskDataArrays.append(bytes)
                sharedMaskSizes.append(size)

                var count = 0
                for k in stride(from: 3, to: bytes.count, by: 4) {
                    if bytes[k] > alphaThreshold { count += 1 }
                }
                sharedMaskOpaqueCounts.append(count)
            }
        }
    }
    
    private func getNormalizedRGBAData(from image: UIImage) -> ([UInt8], CGSize)? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = 4 * width
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(data: &rawData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (rawData, CGSize(width: width, height: height))
    }

    // MARK: - Actions
    @IBAction func traceCompleteTapped(_ sender: Any) {
        for i in 0..<6 {
            if paneShapeLayers[i].strokeColor == UIColor.red.cgColor {
                return
            }
        }
        
        var didAdvanceAny = false
        var allDone = true
        
        for i in 0..<6 {
            let strokeIdx = paneCurrentStrokeIndex[i]
            let totalStrokes = sharedMaskOpaqueCounts.count
            
            if strokeIdx < totalStrokes {
                allDone = false
                let totalPixels = sharedMaskOpaqueCounts[strokeIdx]
                if totalPixels == 0 {
                    paneCurrentStrokeIndex[i] += 1
                    didAdvanceAny = true
                } else {
                    let touched = paneTransientTouchedPixels[i].count
                    let ratio = CGFloat(touched) / CGFloat(totalPixels)
                    if ratio >= coverageThreshold {
                        commitTransientAsGreen(paneIndex: i)
                        paneCurrentStrokeIndex[i] += 1
                        resetTransientLayer(paneIndex: i)
                        didAdvanceAny = true
                    }
                }
            }
            if paneCurrentStrokeIndex[i] >= maskAssetNames.count {
                paneCompleted[i] = true
                resetTransientLayer(paneIndex: i)
            }
        }
        
        if !didAdvanceAny && !allDone {
            flashIncompleteWarning()
        }
        
        let fullyComplete = (0..<6).allSatisfy { i in
            paneCurrentStrokeIndex[i] >= maskAssetNames.count
        }
        if didAdvanceAny {
                    saveIntermediateProgress()
                }
        if fullyComplete {
            onAllStrokesCompleted()
            var touched = 0
            var total = 0

            for i in 0..<6 {
                touched += paneTransientTouchedPixels[i].count
                total += sharedMaskOpaqueCounts.reduce(0, +)
            }

            let penalty = mistakeCount * 10
            let accuracy = max(0, 100 - penalty)

            if accuracy >= 80 {
                showStickerFromBottom(assetName: "sticker")
            }
        }
    }
    
    @IBAction func retryTapped(_ sender: UIButton) {
        let completedCount = paneCompleted.filter { $0 }.count
        
        if completedCount > 0 && completedCount < 6 {
            
            for i in 0..<6 where !paneCompleted[i] {
                clearPaneCompletely(i)
            }
            
            let drawings = committedCanvasViews.map { $0.drawing }
            TracingProgressManager.shared.saveSixWordDrawings(
                drawings,
                index: currentWordIndex,
                category: selectedCategory.rawValue
            )
            
        } else {
            TracingProgressManager.shared.deleteSixWordDrawings(
                index: currentWordIndex,
                category: selectedCategory.rawValue
            )
            for i in 0..<6 {
                clearPaneCompletely(i)
                paneCompleted[i] = false
            }
        }

        isTracingLocked = false
        setCanvasInteraction(true)
        isWordCompleted = false
        traceCompleteButton.backgroundColor = .white
    }
    
    @IBAction func backButtonTapped(_ sender: Any) {
        navigationController?.popToViewController(
            navigationController!.viewControllers.first {
                $0 is WordsCategoriesViewController
            }!,
            animated: true
        )
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
    private func savePartialProgressIfNeeded() {
        let drawings = committedCanvasViews.map { $0.drawing }

        let hasAnyStroke = drawings.contains { !$0.strokes.isEmpty }
        guard hasAnyStroke else { return }

        TracingProgressManager.shared.saveSixWordDrawings(
            drawings,
            index: currentWordIndex,
            category: selectedCategory.rawValue
        )
    }

    private func commitTransientAsGreen(paneIndex: Int) {
        let canvas = committedCanvasViews[paneIndex]
        let segments = paneStrokeSegments[paneIndex]
        guard !segments.isEmpty else { return }
        
        var newStrokes = canvas.drawing.strokes
        let ink = PKInk(.pen, color: .systemGreen)
        let size = CGSize(width: brushWidth, height: brushWidth)
        var time: CGFloat = 0
        
        for segment in segments {
            if segment.count < 2 { continue }
            var points: [PKStrokePoint] = []
            for pt in segment {
                points.append(PKStrokePoint(location: pt, timeOffset: time, size: size, opacity: 1, force: 1, azimuth: 0, altitude: 0))
                time += 0.01
            }
            let path = PKStrokePath(controlPoints: points, creationDate: Date())
            newStrokes.append(PKStroke(ink: ink, path: path))
        }
        canvas.drawing = PKDrawing(strokes: newStrokes)
        paneStrokeSegments[paneIndex].removeAll()
    }
    
    private func setCanvasInteraction(_ enabled: Bool) {
        for canvas in committedCanvasViews {
            canvas.isUserInteractionEnabled = enabled
        }
    }

    private func hardLockTracing() {
        isTracingLocked = true
        activePaneIndex = nil
        setCanvasInteraction(false)
    }
    
    private func resetTransientLayer(paneIndex: Int) {
        panePaths[paneIndex].removeAllPoints()
        paneShapeLayers[paneIndex].path = nil
        paneShapeLayers[paneIndex].strokeColor = UIColor.white.cgColor
        paneCurrentStrokePoints[paneIndex].removeAll()
        paneTransientTouchedPixels[paneIndex].removeAll()
        paneStrokeSegments[paneIndex].removeAll()
    }
    
    private func isCurrentWordCompleted() -> Bool {
        return TracingProgressManager.shared
            .loadSixWordDrawings(
                index: currentWordIndex,
                category: selectedCategory.rawValue
            ) != nil
    }
    
    private func resetFullTrace() {
        for i in 0..<6 {
            resetTransientLayer(paneIndex: i)
            committedCanvasViews[i].drawing = PKDrawing()
            paneCurrentStrokeIndex[i] = 0
        }
        activePaneIndex=nil
        isTracingLocked = false
        setCanvasInteraction(true)
        traceCompleteButton.backgroundColor = .white
    }
    private func clearPaneCompletely(_ index: Int) {
        resetTransientLayer(paneIndex: index)
        committedCanvasViews[index].drawing = PKDrawing()
        paneCurrentStrokeIndex[index] = 0
        paneCompleted[index] = false
        activePaneIndex = nil
    }
    private func saveIntermediateProgress() {
            
            let penalty = mistakeCount * 10
            let performanceScore = max(0, 100 - penalty)
            
            let session = WritingSessionData(
                id: analyticsSessionID,
                date: Date(),
                childId: "default_child",
                lettersAccuracy: 0,
                wordsAccuracy: performanceScore,
                numbersAccuracy: 0
            )
            
            AnalyticsStore.shared.saveOrUpdateWritingSession(session)
        }
    
    private func onAllStrokesCompleted() {
            let drawings = committedCanvasViews.map { $0.drawing }
            TracingProgressManager.shared.saveSixWordDrawings(drawings, index: currentWordIndex, category: selectedCategory.rawValue)
            TracingProgressManager.shared.advanceWordStage(for: selectedCategory.rawValue, currentIndex: currentWordIndex)
            
            let penalty = mistakeCount * 10
            let performanceScore = max(0, 100 - penalty)
            
            let session = WritingSessionData(
                id: analyticsSessionID,
                date: Date(),
                childId: "default_child",
                lettersAccuracy: 0,
                wordsAccuracy: performanceScore,
                numbersAccuracy: 0
            )
            
            AnalyticsStore.shared.saveOrUpdateWritingSession(session)

            TracingProgressManager.shared.saveMistakeCount(0, index: currentWordIndex, category: selectedCategory.rawValue)
            TracingProgressManager.shared.deleteSessionID(index: currentWordIndex, category: selectedCategory.rawValue)
            
            wordsCollectionView.reloadData()
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
            traceCompleteButton.backgroundColor = .systemGreen
            
            isWordCompleted = true
            hardLockTracing()
        }
    
    private func updateNextChevronState() {
        if isCurrentWordCompleted() {
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
            traceCompleteButton.backgroundColor = .systemGreen
        } else {
            nextChevronButton.isEnabled = false
            nextChevronButton.alpha = 0.4
            traceCompleteButton.backgroundColor = .white
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
    
    // MARK: - CollectionView Formatting (Fixed with Lock Logic)
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
            
            let unlockedIdx = TracingProgressManager.shared.highestUnlockedWordIndex(for: selectedCategory.rawValue)
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
            
            button.layer.cornerRadius = 30
            button.clipsToBounds = true
            button.isUserInteractionEnabled = false
            
            if indexPath.item == currentWordIndex {
                button.layer.borderWidth = 3; button.layer.borderColor = UIColor.white.cgColor
            } else {
                button.layer.borderWidth = 0
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let unlockedIdx = TracingProgressManager.shared.highestUnlockedWordIndex(for: selectedCategory.rawValue)
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
