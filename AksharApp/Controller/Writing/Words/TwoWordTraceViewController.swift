//
//  TwoWordTraceViewController.swift
//  AksharApp
//
//  Created by AksharApp on 14/01/26.
//

import UIKit
import PencilKit
import AVFoundation

class TwoWordTraceViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
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
    @IBOutlet weak var backChevronButton: UIButton!
    
    // MARK: - Pane Views
    @IBOutlet weak var topLetterImageView: UIImageView!
    @IBOutlet weak var topCommittedDrawingImageView: UIImageView!
    @IBOutlet weak var topTransientDrawingImageView: UIImageView!

    @IBOutlet weak var bottomLetterImageView: UIImageView!
    @IBOutlet weak var bottomCommittedDrawingImageView: UIImageView!
    @IBOutlet weak var bottomTransientDrawingImageView: UIImageView!
    
    @IBOutlet weak var nextChevronButton: UIButton!
    @IBOutlet weak var traceCompleteButton: UIButton!
    @IBOutlet weak var retryButton: UIButton!
    
    // MARK: - PencilKit & Tracing State
    private var topCommittedCanvasView: PKCanvasView!
    private var bottomCommittedCanvasView: PKCanvasView!
    
    private var topCurrentPath = UIBezierPath()
    private var topShapeLayer: CAShapeLayer!
    private var topStrokeSegments: [[CGPoint]] = []
    private var topCurrentStrokePoints: [CGPoint] = []
    private var topTransientTouchedPixels = Set<Int>()
    private var topCurrentStrokeIndex = 0
    
    private var bottomCurrentPath = UIBezierPath()
    private var bottomShapeLayer: CAShapeLayer!
    private var bottomStrokeSegments: [[CGPoint]] = []
    private var bottomCurrentStrokePoints: [CGPoint] = []
    private var bottomTransientTouchedPixels = Set<Int>()
    private var bottomCurrentStrokeIndex = 0
    
    private enum ActivePane { case top, bottom, none }
    private var currentActivePane: ActivePane = .none
    private var isTracingLocked = false
    private let synthesizer = AVSpeechSynthesizer()
    private var didSetupAfterLayout = false
    private var isWord1Completed = false
    private var isWord2Completed = false
    
    // MARK: - Configuration
    private let coverageThreshold: CGFloat = 0.70
    private let alphaThreshold: UInt8 = 12
    private let deviationResetDelay: TimeInterval = 0.5
    private var brushWidth: CGFloat {
        switch selectedCategory {
        case .threeLetter:
            return 35.0
        case .fourLetter:
            return 30.0
        case .fiveLetter:
            return 25.0
        case .sixLetter:
            return 20.0
        default:
            return 30.0
        }
    }
    
    // MARK: - Mask Data
    private var sharedMasksDataArrays: [[UInt8]] = []
    private var sharedMasksSizes: [CGSize] = []
    private var sharedMasksOpaquePixelCount: [Int] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupUIAppearance()
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
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        savePartialProgressIfNeeded()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        wordsCollectionView.reloadData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didSetupAfterLayout {
            loadMasksForBothPanes()
            alignCanvases()
            didSetupAfterLayout = true
        }
    }
    
    // MARK: - Setup
    private func calculateFullPageAccuracy(
        touched: Int,
        total: Int
    ) -> CGFloat {
        guard total > 0 else { return 0 }
        return (CGFloat(touched) / CGFloat(total)) * 100
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
    }
    
    private func setupTracingViews() {
        func setupPane(_ iv: UIImageView, _ drawingIV: UIImageView, _ transientIV: UIImageView) -> CAShapeLayer {
            iv.isUserInteractionEnabled = false
            drawingIV.isUserInteractionEnabled = false
            drawingIV.backgroundColor = .clear
            transientIV.isUserInteractionEnabled = false
            transientIV.backgroundColor = .clear
            transientIV.image = nil
            iv.contentMode = .scaleAspectFit
            
            let layer = CAShapeLayer()
            layer.strokeColor = UIColor.white.cgColor
            layer.lineWidth = brushWidth
            layer.lineCap = .round
            layer.lineJoin = .round
            layer.fillColor = UIColor.clear.cgColor
            iv.layer.addSublayer(layer)
            layer.frame = iv.bounds
            return layer
        }
        
        topShapeLayer = setupPane(topLetterImageView, topCommittedDrawingImageView, topTransientDrawingImageView)
        bottomShapeLayer = setupPane(bottomLetterImageView, bottomCommittedDrawingImageView, bottomTransientDrawingImageView)
    }
    
    private func setupPencilKitCanvases() {
        func createCanvas(in view: UIView) -> PKCanvasView {
            let canvas = PKCanvasView(frame: .zero)
            canvas.backgroundColor = .clear
            canvas.isOpaque = false
            canvas.tool = PKInkingTool(.pen, color: UIColor.systemGreen, width: brushWidth)
            canvas.isUserInteractionEnabled = false
            canvas.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(canvas)
            NSLayoutConstraint.activate([
                canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                canvas.topAnchor.constraint(equalTo: view.topAnchor),
                canvas.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            return canvas
        }
        topCommittedCanvasView = createCanvas(in: topCommittedDrawingImageView)
        bottomCommittedCanvasView = createCanvas(in: bottomCommittedDrawingImageView)
    }
    
    // MARK: - Word Loading
    private func loadWord(at index: Int) {
        isWord1Completed = false
        isWord2Completed = false
        guard index < words.count else { return }
        mistakeCount = TracingProgressManager.shared.getMistakeCount(index: index, category: selectedCategory.rawValue)
        currentWordIndex = index
        let word = words[index]
        if let image = UIImage(named: word.wordImageName) {
            topLetterImageView.image = image
            bottomLetterImageView.image = image
        }
        
        maskAssetNames = ["\(word.wordImageName)_mask"]
        if let (top, bottom) = TracingProgressManager.shared.loadTwoWordDrawings(
            index: index,
            category: selectedCategory.rawValue
        ) {
            topCommittedCanvasView.drawing = top
            bottomCommittedCanvasView.drawing = bottom

            let unlockedIdx = TracingProgressManager.shared.highestUnlockedWordIndex(for: selectedCategory.rawValue)
            let isHistoricallyDone = index < unlockedIdx
            
            let topHasContent = !top.strokes.isEmpty
            let bottomHasContent = !bottom.strokes.isEmpty

            if isHistoricallyDone {
                isWord1Completed = topHasContent
                isWord2Completed = bottomHasContent
                isTracingLocked = (topHasContent && bottomHasContent)
                if isTracingLocked {
                    traceCompleteButton.backgroundColor = .systemGreen
                } else {
                    traceCompleteButton.backgroundColor = .white
                }
                
                nextChevronButton.isEnabled = true
                nextChevronButton.alpha = 1.0
            } else {
                isTracingLocked = false
                if topHasContent { isWord1Completed = false; topCurrentStrokeIndex = 0 }
                if bottomHasContent { isWord2Completed = false; bottomCurrentStrokeIndex = 0 }
                
                nextChevronButton.isEnabled = true
                nextChevronButton.alpha = 1.0
            }
            resetTransientLayer(pane: .top)
            resetTransientLayer(pane: .bottom)
            topStrokeSegments.removeAll()
            bottomStrokeSegments.removeAll()
            topTransientTouchedPixels.removeAll()
            bottomTransientTouchedPixels.removeAll()

        } else {
            resetFullTrace()
            traceCompleteButton.backgroundColor = .white
            nextChevronButton.isEnabled = false
            nextChevronButton.alpha = 0.4
        }
        
        if didSetupAfterLayout { loadMasksForBothPanes() }
        wordsCollectionView.reloadData()
    }
    
    private func loadMasksForBothPanes() {
        sharedMasksDataArrays.removeAll()
        sharedMasksSizes.removeAll()
        sharedMasksOpaquePixelCount.removeAll()
        
        for name in maskAssetNames {
            guard let image = UIImage(named: name),
                  let (bytes, size) = getNormalizedRGBAData(from: image) else { continue }

            var opaqueCount = 0
            for i in stride(from: 3, to: bytes.count, by: 4) {
                if bytes[i] > alphaThreshold {
                    opaqueCount += 1
                }
            }

            sharedMasksDataArrays.append(bytes)
            sharedMasksSizes.append(size)
            sharedMasksOpaquePixelCount.append(opaqueCount)
        }
    }
    
    private func resetFullTrace() {
        resetAllTransient()
        topCommittedCanvasView.drawing = PKDrawing()
        bottomCommittedCanvasView.drawing = PKDrawing()
        topCurrentStrokeIndex = 0
        bottomCurrentStrokeIndex = 0
        isTracingLocked = false
        isWord1Completed = false
        isWord2Completed = false
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isTracingLocked { return }
        guard let touch = touches.first else { return }

        let locTop = touch.location(in: topLetterImageView)
        let locBottom = touch.location(in: bottomLetterImageView)
        if topLetterImageView.bounds.contains(locTop) {
            guard !isWord1Completed else {
                currentActivePane = .none
                return
            }
            currentActivePane = .top
            topCurrentPath.move(to: locTop)
            topCurrentStrokePoints = [locTop]
            return
        }

        if bottomLetterImageView.bounds.contains(locBottom) {
            guard !isWord2Completed else {
                currentActivePane = .none
                return
            }
            currentActivePane = .bottom
            bottomCurrentPath.move(to: locBottom)
            bottomCurrentStrokePoints = [locBottom]
            return
        }

        currentActivePane = .none
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if currentActivePane == .top && isWord1Completed { return }
        if currentActivePane == .bottom && isWord2Completed { return }
        if isTracingLocked || currentActivePane == .none { return }
        guard let touch = touches.first, let event = event else { return }
        
        if let coalesced = event.coalescedTouches(for: touch) {
            for cTouch in coalesced {
                if currentActivePane == .top {
                    let loc = cTouch.location(in: topLetterImageView)
                    topCurrentPath.addLine(to: loc)
                    topCurrentStrokePoints.append(loc)
                    validatePoint(loc, pane: .top)
                } else {
                    let loc = cTouch.location(in: bottomLetterImageView)
                    bottomCurrentPath.addLine(to: loc)
                    bottomCurrentStrokePoints.append(loc)
                    validatePoint(loc, pane: .bottom)
                }
            }
        }
        
        if currentActivePane == .top && !isWord1Completed {
            topShapeLayer.path = topCurrentPath.cgPath
        }
        else if currentActivePane == .bottom && !isWord2Completed {
            bottomShapeLayer.path = bottomCurrentPath.cgPath
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if currentActivePane == .top && !topCurrentStrokePoints.isEmpty {
            topStrokeSegments.append(topCurrentStrokePoints)
            topCurrentStrokePoints = []
        } else if currentActivePane == .bottom && !bottomCurrentStrokePoints.isEmpty {
            bottomStrokeSegments.append(bottomCurrentStrokePoints)
            bottomCurrentStrokePoints = []
        }
        currentActivePane = .none
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetAllTransient()
        currentActivePane = .none
    }
    
    // MARK: - Tracing Validation
    private func validatePoint(_ point: CGPoint, pane: ActivePane) {
        let isTop = (pane == .top)
        let strokeIndex = isTop ? topCurrentStrokeIndex : bottomCurrentStrokeIndex
        let maskSizes = isTop ? sharedMasksSizes : sharedMasksSizes
        let maskArrays = isTop ? sharedMasksDataArrays : sharedMasksDataArrays
        let imageView = isTop ? topLetterImageView! : bottomLetterImageView!
        let shapeLayer = isTop ? topShapeLayer! : bottomShapeLayer!
        
        guard strokeIndex < maskSizes.count else { return }
        
        let maskSize = maskSizes[strokeIndex]
        let viewSize = imageView.bounds.size
        
        let scale = min(viewSize.width / maskSize.width, viewSize.height / maskSize.height)
        let imageDrawSize = CGSize(width: maskSize.width * scale, height: maskSize.height * scale)
        let xOffset = (viewSize.width - imageDrawSize.width) / 2
        let yOffset = (viewSize.height - imageDrawSize.height) / 2
        
        let px = (point.x - xOffset) / scale
        let py = (point.y - yOffset) / scale
        
        guard px >= 0, py >= 0, px < maskSize.width, py < maskSize.height else { return }
        let imagePoint = CGPoint(x: px, y: py)
        
        if isMaskPixelOpaque(maskData: maskArrays[strokeIndex], maskSize: maskSize, atImagePoint: imagePoint, threshold: alphaThreshold) {
            shapeLayer.strokeColor = UIColor.white.cgColor
            
            let w = Int(maskSize.width)
            let brushRadius = Int(brushWidth / scale)
            let centerX = Int(px), centerY = Int(py)
            
            for dy in -brushRadius...brushRadius {
                for dx in -brushRadius...brushRadius {
                    let x = centerX + dx, y = centerY + dy
                    if x < 0 || y < 0 || x >= w || y >= Int(maskSize.height) { continue }
                    if dx*dx + dy*dy > brushRadius*brushRadius { continue }
                    
                    let idx = y * w + x
                    if isTop { topTransientTouchedPixels.insert(idx) }
                    else { bottomTransientTouchedPixels.insert(idx) }
                }
            }
        } else {
            triggerDeviation(pane: pane)
        }
    }
    
    private func isMaskPixelOpaque(maskData: [UInt8], maskSize: CGSize, atImagePoint point: CGPoint, threshold: UInt8) -> Bool {
        let width = Int(maskSize.width)
        let x = Int(point.x), y = Int(point.y)
        let pixelIndex = (y * width + x) * 4
        if pixelIndex + 3 >= maskData.count { return false }
        return maskData[pixelIndex + 3] > threshold
    }
    

    
    private func triggerDeviation(pane: ActivePane) {
        if isTracingLocked { return }
        mistakeCount += 1
        TracingProgressManager.shared.saveMistakeCount(mistakeCount, index: currentWordIndex, category: selectedCategory.rawValue)
        isTracingLocked = true
        let layer = (pane == .top) ? topShapeLayer! : bottomShapeLayer!
        layer.strokeColor = UIColor.red.cgColor
        
        DispatchQueue.main.asyncAfter(deadline: .now() + deviationResetDelay) {
            self.resetTransientLayer(pane: pane)
            self.isTracingLocked = false
        }
    }
    
    // MARK: - Trace Commit
    private func commitTransientAsGreen(pane: ActivePane) {
        let canvas = (pane == .top) ? topCommittedCanvasView! : bottomCommittedCanvasView!
        let segments = (pane == .top) ? topStrokeSegments : bottomStrokeSegments
        guard !segments.isEmpty else { return }
        
        var newStrokes: [PKStroke] = canvas.drawing.strokes
        let size = CGSize(width: brushWidth, height: brushWidth)
        var time: CGFloat = 0
        
        for segment in segments {
            guard segment.count > 1 else { continue }
            var pkPoints: [PKStrokePoint] = []
            for pt in segment {
                pkPoints.append(PKStrokePoint(location: pt, timeOffset: time, size: size, opacity: 1, force: 1, azimuth: 0, altitude: 0))
                time += 0.01
            }
            let path = PKStrokePath(controlPoints: pkPoints, creationDate: Date())
            newStrokes.append(PKStroke(ink: PKInk(.pen, color: .systemGreen), path: path))
        }
        canvas.drawing = PKDrawing(strokes: newStrokes)
        
        if pane == .top { topStrokeSegments.removeAll() }
        else { bottomStrokeSegments.removeAll() }
    }
    
    private func onAllStrokesCompleted() {
            TracingProgressManager.shared.saveTwoWordDrawings(
                top: topCommittedCanvasView.drawing,
                bottom: bottomCommittedCanvasView.drawing,
                index: currentWordIndex,
                category: selectedCategory.rawValue
            )
            
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
            traceCompleteButton.backgroundColor = .systemGreen
            
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
    
    // MARK: - Reset Helper
    private func resetAllTransient() {
        resetTransientLayer(pane: .top)
        resetTransientLayer(pane: .bottom)
    }

    private func resetTransientLayer(pane: ActivePane) {
        if pane == .top {
            topCurrentPath.removeAllPoints(); topShapeLayer.path = nil; topShapeLayer.strokeColor = UIColor.white.cgColor
            topStrokeSegments.removeAll(); topCurrentStrokePoints.removeAll(); topTransientTouchedPixels.removeAll()
        } else {
            bottomCurrentPath.removeAllPoints(); bottomShapeLayer.path = nil; bottomShapeLayer.strokeColor = UIColor.white.cgColor
            bottomStrokeSegments.removeAll(); bottomCurrentStrokePoints.removeAll(); bottomTransientTouchedPixels.removeAll()
        }
    }
    
    private func clearTopPaneCompletely() {
        resetTransientLayer(pane: .top)
        topCommittedCanvasView.drawing = PKDrawing()
        topCurrentStrokeIndex = 0
    }

    private func clearBottomPaneCompletely() {
        resetTransientLayer(pane: .bottom)
        bottomCommittedCanvasView.drawing = PKDrawing()
        bottomCurrentStrokeIndex = 0
    }
    
    // MARK: - UI Helpers
    private func savePartialProgressIfNeeded() {
        let topHasStroke = !topCommittedCanvasView.drawing.strokes.isEmpty
        let bottomHasStroke = !bottomCommittedCanvasView.drawing.strokes.isEmpty

        guard topHasStroke || bottomHasStroke else { return }

        TracingProgressManager.shared.saveTwoWordDrawings(
            top: topCommittedCanvasView.drawing,
            bottom: bottomCommittedCanvasView.drawing,
            index: currentWordIndex,
            category: selectedCategory.rawValue
        )
    }
    
    private func getNormalizedRGBAData(from image: UIImage) -> ([UInt8], CGSize)? {
        guard let cgImage = image.cgImage else { return nil }
        let w = cgImage.width; let h = cgImage.height
        let bytesPerRow = 4 * w
        var rawData = [UInt8](repeating: 0, count: h * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &rawData, width: w, height: h, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (rawData, CGSize(width: w, height: h))
    }

    private func alignCanvases() {
        topShapeLayer.frame = topLetterImageView.bounds
        bottomShapeLayer.frame = bottomLetterImageView.bounds
        topCommittedCanvasView.setNeedsDisplay()
        bottomCommittedCanvasView.setNeedsDisplay()
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
    
    // MARK: - Actions
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
    
    @IBAction func traceCompleteTapped(_ sender: Any) {
        if topShapeLayer.strokeColor == UIColor.red.cgColor || bottomShapeLayer.strokeColor == UIColor.red.cgColor { return
        }
        
        var didAdvanceTop = false; var didAdvanceBottom = false
        if topCurrentStrokeIndex < sharedMasksOpaquePixelCount.count {
            let total = sharedMasksOpaquePixelCount[topCurrentStrokeIndex]
            if total == 0 { topCurrentStrokeIndex += 1; didAdvanceTop = true }
            else if !topTransientTouchedPixels.isEmpty {
                commitTransientAsGreen(pane: .top); topCurrentStrokeIndex += 1; resetTransientLayer(pane: .top); didAdvanceTop = true
            }
        }
        if bottomCurrentStrokeIndex < sharedMasksOpaquePixelCount.count {
            let total = sharedMasksOpaquePixelCount[bottomCurrentStrokeIndex]
            if total == 0 { bottomCurrentStrokeIndex += 1; didAdvanceBottom = true }
            else if !bottomTransientTouchedPixels.isEmpty {
                commitTransientAsGreen(pane: .bottom); bottomCurrentStrokeIndex += 1; resetTransientLayer(pane: .bottom); didAdvanceBottom = true
            }
        }
        if topCurrentStrokeIndex >= maskAssetNames.count { isWord1Completed = true }
        if bottomCurrentStrokeIndex >= maskAssetNames.count { isWord2Completed = true }
        
        if !didAdvanceTop && !didAdvanceBottom {
            if !(topCurrentStrokeIndex >= maskAssetNames.count && bottomCurrentStrokeIndex >= maskAssetNames.count) {
                flashIncompleteWarning()
            }
        }
        
        if topCurrentStrokeIndex >= maskAssetNames.count && bottomCurrentStrokeIndex >= maskAssetNames.count {
            onAllStrokesCompleted()
            isWord1Completed = true
            isWord2Completed = true

            let penalty = mistakeCount * 10
            let accuracy = max(0, 100 - penalty)

            if accuracy >= 80 {
                showStickerFromBottom(assetName: "sticker")
            }
            
        }
    }
    
    @IBAction func retryTapped(_ sender: UIButton) {
        let topDone = isWord1Completed
        let bottomDone = isWord2Completed
        
        if topDone && !bottomDone {
            
            clearBottomPaneCompletely()
            isWord2Completed = false
            
            TracingProgressManager.shared.saveTwoWordDrawings(
                top: topCommittedCanvasView.drawing,
                bottom: PKDrawing(),
                index: currentWordIndex,
                category: selectedCategory.rawValue
            )
            
        } else if bottomDone && !topDone {
            
            clearTopPaneCompletely()
            isWord1Completed = false
            
            TracingProgressManager.shared.saveTwoWordDrawings(
                top: PKDrawing(),
                bottom: bottomCommittedCanvasView.drawing,
                index: currentWordIndex,
                category: selectedCategory.rawValue
            )
            
        } else {
            
            TracingProgressManager.shared.deleteTwoWordDrawings(
                index: currentWordIndex,
                category: selectedCategory.rawValue
            )
            clearTopPaneCompletely()
            clearBottomPaneCompletely()
            isWord1Completed = false
            isWord2Completed = false
        }
        
        topCurrentStrokeIndex = 0
        bottomCurrentStrokeIndex = 0
        isTracingLocked = false
        currentActivePane = .none
        traceCompleteButton.backgroundColor = .white
    }
    
    // MARK: - CollectionView
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
