//
//  TwoLetterTraceViewController.swift
//  AksharApp
//

import UIKit
import PencilKit
import AVFoundation

class TwoLetterTraceViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Properties
    var contentType: WritingContentType = .letters
    var currentLetterIndex: Int = 0
    private var analyticsSessionID: UUID!
    
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
    @IBOutlet weak var topTransientDrawingImageView: UIImageView!

    @IBOutlet weak var bottomLetterImageView: UIImageView!
    @IBOutlet weak var bottomCommittedDrawingImageView: UIImageView!
    @IBOutlet weak var bottomTransientDrawingImageView: UIImageView!
    
    // MARK: - PencilKit & Tracing State
    private var topCommittedCanvasView: PKCanvasView!
    private var bottomCommittedCanvasView: PKCanvasView!
    
    //MARK: - Top Pane State
    private var topCurrentPath = UIBezierPath()
    private var topShapeLayer: CAShapeLayer!
    private var topStrokeSegments: [[CGPoint]] = []
    private var topCurrentStrokePoints: [CGPoint] = []
    private var topTransientTouchedPixels = Set<Int>()
    private var topCurrentStrokeIndex = 0
    private var isTopCompleted = false
    
    //MARK: - Bottom Pane State
    private var bottomCurrentPath = UIBezierPath()
    private var bottomShapeLayer: CAShapeLayer!
    private var bottomStrokeSegments: [[CGPoint]] = []
    private var bottomCurrentStrokePoints: [CGPoint] = []
    private var bottomTransientTouchedPixels = Set<Int>()
    private var bottomCurrentStrokeIndex = 0
    private var isBottomCompleted = false
    
    //MARK: - Global Tracing State
    private enum ActivePane { case top, bottom, none }
    private var currentActivePane: ActivePane = .none
    private var isTracingLocked = false
    private let synthesizer = AVSpeechSynthesizer()
    private var didSetupAfterLayout = false

    // MARK: - Configuration
    private let brushWidth: CGFloat = 35.0
    private let coverageThreshold: CGFloat = 0.30
    private let alphaThreshold: UInt8 = 12
    private let deviationResetDelay: TimeInterval = 0.5
    
    // MARK: - Data Models
    private var maskAssetNames: [String] = []
    private var letterAssetName = "A"
    private var mistakeCount = 0
    
    //MARK: - Top Mask Data
    private var topMaskDataArrays: [[UInt8]] = []
    private var topMaskSizes: [CGSize] = []
    private var topMaskOpaquePixelCount: [Int] = []
    
    //MARK: - Bottom Mask Data
    private var bottomMaskDataArrays: [[UInt8]] = []
    private var bottomMaskSizes: [CGSize] = []
    private var bottomMaskOpaquePixelCount: [Int] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        let categoryKey = (contentType == .letters) ? "letters" : "numbers"
                if let savedID = TracingProgressManager.shared.getSessionID(index: currentLetterIndex, category: categoryKey) {
                    analyticsSessionID = savedID
                } else {
                    analyticsSessionID = UUID()
                    TracingProgressManager.shared.saveSessionID(analyticsSessionID, index: currentLetterIndex, category: categoryKey)
                }
        setupCollectionView()
        setupUIAppearance()
        setupTracingViews()
        setupPencilKitCanvases()
        
        showLetter(at: currentLetterIndex)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNextChevronState()
        alphabetCollectionView.reloadData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didSetupAfterLayout {
            loadMasksForBothPanes()
            alignCanvases()
            didSetupAfterLayout = true
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        savePartialProgressIfNeeded()
    }
    
    // MARK: - Setup Methods
    private func calculateFullPageAccuracy(
        touched: Int,
        total: Int
    ) -> CGFloat {
        guard total > 0 else { return 0 }
        return (CGFloat(touched) / CGFloat(total)) * 100
    }

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
        
        func style(_ view: UIView, border: CGColor) {
            view.layer.borderColor = border
            view.layer.borderWidth = 3
        }
        
        style(speakerButton, border: brownColor)
        style(retryButton, border: brownColor)
        style(traceCompleteButton, border: brownColor)
        
        yellowView.layer.cornerRadius = 25
        alphabetCollectionView.layer.borderColor = yellowColor
        alphabetCollectionView.layer.borderWidth = 2
        alphabetCollectionView.layer.cornerRadius = 20
        retryButton.isHidden = false
        
        nextChevronButton.isEnabled = false
        nextChevronButton.alpha = 0.4
        speakerButton.isUserInteractionEnabled = true
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
        
        if let letterImage = UIImage(named: letterAssetName) {
            topLetterImageView.image = letterImage
            bottomLetterImageView.image = letterImage
        }
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
    
    private func alignCanvases() {
        topShapeLayer.frame = topLetterImageView.bounds
        bottomShapeLayer.frame = bottomLetterImageView.bounds
        topCommittedCanvasView.setNeedsDisplay()
        bottomCommittedCanvasView.setNeedsDisplay()
    }
    
    // MARK: - Logic & Content Loading
    private func showLetter(at index: Int) {
        let idx = max(0, index)
        currentLetterIndex = idx
        let categoryKey = (contentType == .letters) ? "letters" : "numbers"
                mistakeCount = TracingProgressManager.shared.getMistakeCount(index: idx, category: categoryKey)
        topLetterImageView.tintColor = nil
        bottomLetterImageView.tintColor = nil

        switch contentType {
        case .letters:
            let safeIdx = min(25, idx)
            let letterChar = String(UnicodeScalar(65 + safeIdx)!)
            if let letterImg = UIImage(named: "letter_\(letterChar)") {
                topLetterImageView.image = letterImg; bottomLetterImageView.image = letterImg
            } else {
                let fallback = UIImage(named: letterChar)
                topLetterImageView.image = fallback; bottomLetterImageView.image = fallback
            }
            maskAssetNames = ["\(letterChar)_mask"]

        case .numbers:
            let img = UIImage(named: "number_\(idx)")
            topLetterImageView.image = img; bottomLetterImageView.image = img
            maskAssetNames = ["\(idx)_mask"]
        }
        
        if let (top, bottom) = TracingProgressManager.shared.loadTwoLetterDrawings(
            index: currentLetterIndex,
            type: contentType
        ) {
            topCommittedCanvasView.drawing = top
            bottomCommittedCanvasView.drawing = bottom

            if !top.strokes.isEmpty {
                isTopCompleted = true
                topCurrentStrokeIndex = maskAssetNames.count
            } else {
                isTopCompleted = false
                topCurrentStrokeIndex = 0
            }

            if !bottom.strokes.isEmpty {
                isBottomCompleted = true
                bottomCurrentStrokeIndex = maskAssetNames.count
            } else {
                isBottomCompleted = false
                bottomCurrentStrokeIndex = 0
            }

            isTracingLocked = false   
        } else {
            topCommittedCanvasView.drawing = PKDrawing()
            bottomCommittedCanvasView.drawing = PKDrawing()

            isTopCompleted = false
            isBottomCompleted = false
            topCurrentStrokeIndex = 0
            bottomCurrentStrokeIndex = 0
            isTracingLocked = false
        }

        if didSetupAfterLayout { loadMasksForBothPanes() }
        
        resetTransientLayer(pane: .top)
        resetTransientLayer(pane: .bottom)
        alphabetCollectionView.reloadData()
        view.bringSubviewToFront(topLetterImageView)
        view.bringSubviewToFront(bottomLetterImageView)
    }
    
    private func loadMasksForBothPanes() {
        topMaskDataArrays.removeAll(); topMaskSizes.removeAll(); topMaskOpaquePixelCount.removeAll()
        bottomMaskDataArrays.removeAll(); bottomMaskSizes.removeAll(); bottomMaskOpaquePixelCount.removeAll()
        
        for name in maskAssetNames {
            guard let image = UIImage(named: name),
                  let (bytes, size) = getNormalizedRGBAData(from: image) else { continue }

            var opaqueCount = 0
            for i in stride(from: 3, to: bytes.count, by: 4) {
                if bytes[i] > alphaThreshold {
                    opaqueCount += 1
                }
            }

            topMaskDataArrays.append(bytes)
            topMaskSizes.append(size)
            topMaskOpaquePixelCount.append(opaqueCount)

            bottomMaskDataArrays.append(bytes)
            bottomMaskSizes.append(size)
            bottomMaskOpaquePixelCount.append(opaqueCount)
        }
    }

    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isTracingLocked { return }
        guard let touch = touches.first else { return }

        let locTop = touch.location(in: topLetterImageView)
        let locBottom = touch.location(in: bottomLetterImageView)

        if topLetterImageView.bounds.contains(locTop) {
            guard !isTopCompleted else {
                currentActivePane = .none
                return
            }
            currentActivePane = .top
            topCurrentPath.move(to: locTop)
            topCurrentStrokePoints = [locTop]
            return
        }

        if bottomLetterImageView.bounds.contains(locBottom) {
            guard !isBottomCompleted else {
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
        if currentActivePane == .top && isTopCompleted { return }
        if currentActivePane == .bottom && isBottomCompleted { return }
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
        
        if currentActivePane == .top { topShapeLayer.path = topCurrentPath.cgPath }
        else { bottomShapeLayer.path = bottomCurrentPath.cgPath }
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

    // MARK: - Tracing Validation & Logic
    private func validatePoint(_ point: CGPoint, pane: ActivePane) {
        let isTop = (pane == .top)
        let strokeIndex = isTop ? topCurrentStrokeIndex : bottomCurrentStrokeIndex
        let maskSizes = isTop ? topMaskSizes : bottomMaskSizes
        let maskArrays = isTop ? topMaskDataArrays : bottomMaskDataArrays
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
            
            let w = Int(maskSize.width), h = Int(maskSize.height)
            let brushRadius = Int(brushWidth / scale)
            let centerX = Int(px), centerY = Int(py)
            
            for dy in -brushRadius...brushRadius {
                for dx in -brushRadius...brushRadius {
                    let x = centerX + dx, y = centerY + dy
                    if x < 0 || y < 0 || x >= w || y >= h { continue }
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
        let categoryKey = (contentType == .letters) ? "letters" : "numbers"
                TracingProgressManager.shared.saveMistakeCount(mistakeCount, index: currentLetterIndex, category: categoryKey)
        print("Mistake on \(pane) pane! Total: \(mistakeCount)")
        isTracingLocked = true
        let layer = (pane == .top) ? topShapeLayer! : bottomShapeLayer!
        layer.strokeColor = UIColor.red.cgColor
        
        DispatchQueue.main.asyncAfter(deadline: .now() + deviationResetDelay) {
            self.resetTransientLayer(pane: pane)
            self.isTracingLocked = false
        }
    }
    
    private func handleDeviation() {
        if topShapeLayer.strokeColor == UIColor.red.cgColor {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.resetTransientLayer(pane: .top) }
        }
        if bottomShapeLayer.strokeColor == UIColor.red.cgColor {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.resetTransientLayer(pane: .bottom) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.isTracingLocked = false }
    }
    
    private func resetTransientLayer(pane: ActivePane) {
        if pane == .top {
            topCurrentPath.removeAllPoints()
            topShapeLayer.path = nil
            topShapeLayer.strokeColor = UIColor.white.cgColor
            topStrokeSegments.removeAll()
            topCurrentStrokePoints.removeAll()
            topTransientTouchedPixels.removeAll()
        } else {
            bottomCurrentPath.removeAllPoints()
            bottomShapeLayer.path = nil
            bottomShapeLayer.strokeColor = UIColor.white.cgColor
            bottomStrokeSegments.removeAll()
            bottomCurrentStrokePoints.removeAll()
            bottomTransientTouchedPixels.removeAll()
        }
    }
    
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
        savePartialProgressIfNeeded()
    }
    
    private func onAllStrokesCompleted() {
            TracingProgressManager.shared.saveTwoLetterDrawings(
                top: topCommittedCanvasView.drawing,
                bottom: bottomCommittedCanvasView.drawing,
                index: currentLetterIndex,
                type: contentType
            )
            alphabetCollectionView.reloadData()
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
            let penalty = mistakeCount * 10
            saveIntermediateProgress()
            let performanceScore = max(0, 100 - penalty)
            
            print("Two Letter Session Complete. Total Mistakes: \(mistakeCount) | Final Score: \(performanceScore)")
            let session = WritingSessionData(
                id: UUID(),
                date: Date(),
                childId: "default_child",
                lettersAccuracy: contentType == .letters ? performanceScore : 0,
                wordsAccuracy: 0,
                numbersAccuracy: contentType == .numbers ? performanceScore : 0
            )
            AnalyticsStore.shared.appendWritingSession(session)
        let categoryKey = (contentType == .letters) ? "letters" : "numbers"
                TracingProgressManager.shared.saveMistakeCount(0, index: currentLetterIndex, category: categoryKey)
        }
    
    private func saveIntermediateProgress() {
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
            
            AnalyticsStore.shared.saveOrUpdateWritingSession(session)
        }

    // MARK: - Actions
    @IBAction func backTapped(_ sender: UIButton) {
        goBack()
    }
    @IBAction func homeTapped(_ sender: UIButton) {
        goHome()
    }
    @IBAction func nextChevronTapped(_ sender: Any) {
        navigateNext()
    }
    
    @IBAction func speakerButtonTapped(_ sender: UIButton) {
        let textToSpeak = (contentType == .letters) ? String(UnicodeScalar(65 + currentLetterIndex)!) : "\(currentLetterIndex)"
        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
    
    @IBAction func letterButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index <= TracingProgressManager.shared.highestUnlockedIndex(for: contentType) else { return }
        let vc = storyboard!.instantiateViewController(withIdentifier: "OneLetterTraceVC") as! OneLetterTraceViewController
        vc.contentType = contentType
        vc.currentLetterIndex = index
        navigationController?.pushViewController(vc, animated: false)
    }
    
    @IBAction func traceCompleteTapped(_ sender: Any) {
        if topShapeLayer.strokeColor == UIColor.red.cgColor || bottomShapeLayer.strokeColor == UIColor.red.cgColor {
            handleDeviation(); return
        }
        
        var didAdvanceTop = false
        var didAdvanceBottom = false
        
        if topCurrentStrokeIndex < topMaskOpaquePixelCount.count {
            let total = topMaskOpaquePixelCount[topCurrentStrokeIndex]
            if total == 0 { topCurrentStrokeIndex += 1; didAdvanceTop = true }
            else if CGFloat(topTransientTouchedPixels.count) / CGFloat(total) >= coverageThreshold {
                commitTransientAsGreen(pane: .top)
                topCurrentStrokeIndex += 1
                resetTransientLayer(pane: .top)
                didAdvanceTop = true
            }
            if topCurrentStrokeIndex >= maskAssetNames.count && bottomCurrentStrokeIndex >= maskAssetNames.count {
                        onAllStrokesCompleted()
                    }
        }
        
        if bottomCurrentStrokeIndex < bottomMaskOpaquePixelCount.count {
            let total = bottomMaskOpaquePixelCount[bottomCurrentStrokeIndex]
            if total == 0 { bottomCurrentStrokeIndex += 1; didAdvanceBottom = true }
            else if CGFloat(bottomTransientTouchedPixels.count) / CGFloat(total) >= coverageThreshold {
                commitTransientAsGreen(pane: .bottom)
                bottomCurrentStrokeIndex += 1
                resetTransientLayer(pane: .bottom)
                didAdvanceBottom = true
            }
        }
        
        if !didAdvanceTop && !didAdvanceBottom {
            let allDone = (topCurrentStrokeIndex >= maskAssetNames.count && bottomCurrentStrokeIndex >= maskAssetNames.count)
            if !allDone { flashIncompleteWarning() }
        }
        
        if topCurrentStrokeIndex >= maskAssetNames.count && bottomCurrentStrokeIndex >= maskAssetNames.count {
            onAllStrokesCompleted()
            let penalty = mistakeCount * 10
            let accuracy = max(0, 100 - penalty)

            if accuracy >= 80 {
                showStickerFromBottom(assetName: "sticker")
            }

        }
        if topCurrentStrokeIndex >= maskAssetNames.count {
            isTopCompleted = true
            resetTransientLayer(pane: .top)
        }
        if bottomCurrentStrokeIndex >= maskAssetNames.count {
            isBottomCompleted = true
            resetTransientLayer(pane: .bottom)
        }
    }
    
    @IBAction func previousChevronTapped(_ sender: UIButton) {
        let targetIndex = currentLetterIndex
        if let nav = navigationController,
           let prevVC = nav.viewControllers.dropLast().last as? OneLetterTraceViewController,
           prevVC.currentLetterIndex == targetIndex, prevVC.contentType == self.contentType {
            nav.popViewController(animated: false)
        } else {
            let vc = storyboard!.instantiateViewController(withIdentifier: "OneLetterTraceVC") as! OneLetterTraceViewController
            vc.contentType = contentType; vc.currentLetterIndex = targetIndex
            navigationController?.pushViewController(vc, animated: false)
        }
    }
    
    @IBAction func retryTapped(_ sender: UIButton) {
        
        let topCompleted = isTopCompleted
        let bottomCompleted = isBottomCompleted

        switch (topCompleted, bottomCompleted) {
        case (true, false):
            resetBottomOnly()
            isBottomCompleted = false

        case (false, true):
            resetTopOnly()
            isTopCompleted = false

        case (true, true), (false, false):
            resetTopOnly()
            resetBottomOnly()
            isTopCompleted = false
            isBottomCompleted = false
        }
    }

    // MARK: - Helpers
    private func resetTopOnly() {
        resetTransientLayer(pane: .top)
        topCommittedCanvasView.drawing = PKDrawing()
        topCurrentStrokeIndex = 0
    }

    private func resetBottomOnly() {
        resetTransientLayer(pane: .bottom)
        bottomCommittedCanvasView.drawing = PKDrawing()
        bottomCurrentStrokeIndex = 0
    }
    private func navigateNext() {
        let vc = storyboard!.instantiateViewController(withIdentifier: "SixLetterTraceVC") as! SixLetterTraceViewController
        vc.contentType = contentType
        vc.currentLetterIndex = currentLetterIndex
        navigationController?.pushViewController(vc, animated: false)
    }
    
    private func resetFullTrace() {
        TracingProgressManager.shared.deleteTwoLetterDrawings(
            index: currentLetterIndex,
            type: contentType
        )

        resetAllTransient()
        topCommittedCanvasView.drawing = PKDrawing()
        bottomCommittedCanvasView.drawing = PKDrawing()
        topCurrentStrokeIndex = 0
        bottomCurrentStrokeIndex = 0
    }
    
    private func resetAllTransient() {
        resetTransientLayer(pane: .top)
        resetTransientLayer(pane: .bottom)
        isTracingLocked = false
    }
    
    private func updateNextChevronState() {
        let unlocked = TracingProgressManager.shared.highestUnlockedIndex(for: contentType)
        if currentLetterIndex < unlocked {
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
            return
        }
        let isCompleted = TracingProgressManager.shared.isTwoLetterCompleted(
            index: currentLetterIndex,
            type: contentType
        )

        nextChevronButton.isEnabled = isCompleted
        nextChevronButton.alpha = isCompleted ? 1.0 : 0.4
    }
    
    func goHome() {
        navigationController?.popToRootViewController(animated: true)
    }

    func goBack() {
        guard let nav = navigationController else { return }
        for controller in nav.viewControllers {
            if String(describing: type(of: controller)).contains("WritingPreview") {
                nav.popToViewController(controller, animated: true); return
            }
        }
        nav.popViewController(animated: true)
    }
    
    // MARK: - Helper Methods
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
    
    private func savePartialProgressIfNeeded() {
        let topHasProgress = !topCommittedCanvasView.drawing.strokes.isEmpty
        let bottomHasProgress = !bottomCommittedCanvasView.drawing.strokes.isEmpty
        
        guard topHasProgress || bottomHasProgress else { return }

        TracingProgressManager.shared.saveTwoLetterDrawings(
            top: topCommittedCanvasView.drawing,
            bottom: bottomCommittedCanvasView.drawing,
            index: currentLetterIndex,
            type: contentType
        )
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
        
        let unlockedIndex = TracingProgressManager.shared.highestUnlockedIndex(for: contentType)
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
        let unlocked = TracingProgressManager.shared.highestUnlockedIndex(for: contentType)
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

