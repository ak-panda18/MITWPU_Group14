//
//  SixLetterTraceViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit
import PencilKit
import AVFoundation

class SixLetterTraceViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Properties
    var contentType: WritingContentType = .letters
    var currentLetterIndex: Int = 0
    private var mistakeCount = 0
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
    
    // MARK: - Pane Collections (For Iteration)
    private var letterImageViews: [UIImageView] = []
    private var committedImageViews: [UIImageView] = []
    private var transientImageViews: [UIImageView] = []
    private var committedCanvasViews: [PKCanvasView] = []
    
    // MARK: - Tracing State (One per pane)
    private var paneShapeLayers: [CAShapeLayer] = []
    private var panePaths: [UIBezierPath] = []
    private var paneStrokeSegments: [[[CGPoint]]] = Array(repeating: [], count: 6)
    private var paneCurrentStrokePoints: [[CGPoint]] = Array(repeating: [], count: 6)
    private var paneTransientTouchedPixels: [Set<Int>] = Array(repeating: Set<Int>(), count: 6)
    private var paneCurrentStrokeIndex: [Int] = Array(repeating: 0, count: 6)
    private var paneCompleted: [Bool] = Array(repeating: false, count: 6)
    
    // MARK: - Mask Data (One per pane)
    private var maskAssetNames: [String] = []
    private var paneMaskDataArrays: [[[UInt8]]] = Array(repeating: [], count: 6)
    private var paneMaskSizes: [[CGSize]] = Array(repeating: [], count: 6)
    private var paneMaskOpaqueCounts: [[Int]] = Array(repeating: [], count: 6)
    
    // MARK: - Logic & Configuration
    private var activePaneIndex: Int? = nil
    private var isTracingLocked = false
    private let synthesizer = AVSpeechSynthesizer()
    private var didSetupAfterLayout = false
    
    private let brushWidth: CGFloat = 20.0
    private let coverageThreshold: CGFloat = 0.30
    private let alphaThreshold: UInt8 = 12
    private let deviationResetDelay: TimeInterval = 0.5
    
    private var boxAssetBaseName = "box_a"

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
        setupArrays()
        setupUI()
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
            loadMasksForAllPanes()
            alignLayers()
            didSetupAfterLayout = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        savePartialProgressIfNeeded()
    }
    
    // MARK: - Setup Methods
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
        alphabetCollectionView.delegate = self
        alphabetCollectionView.dataSource = self
        
        if let layout = alphabetCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
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
        alphabetCollectionView.layer.borderColor = yellowColor
        alphabetCollectionView.layer.borderWidth = 2
        alphabetCollectionView.layer.cornerRadius = 20
        retryButton.isHidden = false
        speakerButton.isUserInteractionEnabled = true
        
        nextChevronButton.isEnabled = false
        nextChevronButton.alpha = 0.4
    }
    
    private func setupTracingViews() {
        for i in 0..<6 {
            let letterIV = letterImageViews[i]
            let transientIV = transientImageViews[i]
            let committedIV = committedImageViews[i]
            
            letterIV.isUserInteractionEnabled = false
            letterIV.contentMode = .scaleAspectFit
            transientIV.isUserInteractionEnabled = false
            transientIV.backgroundColor = .clear
            committedIV.isUserInteractionEnabled = false
            committedIV.backgroundColor = .clear
            
            let shapeLayer = paneShapeLayers[i]
            shapeLayer.strokeColor = UIColor.white.cgColor
            shapeLayer.lineWidth = brushWidth
            shapeLayer.lineCap = .round
            shapeLayer.lineJoin = .round
            shapeLayer.fillColor = UIColor.clear.cgColor
            letterIV.layer.addSublayer(shapeLayer)
            shapeLayer.frame = letterIV.bounds
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
            if paneCompleted[i] { continue }   // 🔒 KEY LINE
            let loc = touch.location(in: letterImageViews[i])
            if letterImageViews[i].bounds.contains(loc) {
                activePaneIndex = i
                panePaths[i].move(to: loc)
                paneCurrentStrokePoints[i] = [loc]
                validatePoint(loc, paneIndex: i)
                break
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isTracingLocked { return }
        guard let idx = activePaneIndex else { return }
        guard let touch = touches.first, let event = event else { return }
        
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

    // MARK: - Validation Logic
    private func validatePoint(_ point: CGPoint, paneIndex: Int) {
        if isTracingLocked { return }
        let strokeIdx = paneCurrentStrokeIndex[paneIndex]
        guard strokeIdx < paneMaskSizes[paneIndex].count else { return }

        let maskSize = paneMaskSizes[paneIndex][strokeIdx]
        let imageView = letterImageViews[paneIndex]
        let viewSize = imageView.bounds.size
        
        let scale = min(viewSize.width / maskSize.width, viewSize.height / maskSize.height)
        let imageDrawSize = CGSize(width: maskSize.width * scale, height: maskSize.height * scale)
        let xOffset = (viewSize.width - imageDrawSize.width) / 2
        let yOffset = (viewSize.height - imageDrawSize.height) / 2

        let px = (point.x - xOffset) / scale
        let py = (point.y - yOffset) / scale
        
        guard px >= 0, py >= 0, px < maskSize.width, py < maskSize.height else {
            triggerDeviation(paneIndex: paneIndex)
            return
        }

        let imagePoint = CGPoint(x: px, y: py)
        let maskData = paneMaskDataArrays[paneIndex][strokeIdx]

        if isMaskPixelOpaque(maskData: maskData, maskSize: maskSize, atImagePoint: imagePoint) {
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
        let categoryKey = (contentType == .letters) ? "letters" : "numbers"
                TracingProgressManager.shared.saveMistakeCount(mistakeCount, index: currentLetterIndex, category: categoryKey)
        isTracingLocked = true
        paneShapeLayers[paneIndex].strokeColor = UIColor.red.cgColor
        
        DispatchQueue.main.asyncAfter(deadline: .now() + deviationResetDelay) {
            self.resetTransientLayer(paneIndex: paneIndex)
            self.isTracingLocked = false
        }
    }
    
    private func handleDeviation() {
        for i in 0..<6 {
            if paneShapeLayers[i].strokeColor == UIColor.red.cgColor {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.resetTransientLayer(paneIndex: i)
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isTracingLocked = false
        }
    }

    // MARK: - Logic & Content Loading
    private func showLetter(at index: Int) {
        let idx = max(0, index)
        currentLetterIndex = idx
        let categoryKey = (contentType == .letters) ? "letters" : "numbers"
                mistakeCount = TracingProgressManager.shared.getMistakeCount(index: idx, category: categoryKey)
        switch contentType {
        case .letters:
            let safeIdx = min(25, idx)
            let letterChar = String(UnicodeScalar(65 + safeIdx)!)
            boxAssetBaseName = "box_\(letterChar.lowercased())"
            
            let letterImg = UIImage(named: "letter_\(letterChar)") ?? UIImage(named: letterChar)
            for i in 0...3 { letterImageViews[i].image = letterImg; letterImageViews[i].tintColor = nil }

            if let boxImg = UIImage(named: boxAssetBaseName) {
                pane5LetterImageView.image = boxImg; pane6LetterImageView.image = boxImg
            } else {
                pane5LetterImageView.image = letterImg; pane6LetterImageView.image = letterImg
            }
            pane5LetterImageView.tintColor = nil; pane6LetterImageView.tintColor = nil

            var letterMasks: [String] = []
            for i in 1...4 {
                let name = "\(letterChar)_mask_\(i)"
                if UIImage(named: name) != nil { letterMasks.append(name) }
            }
            if letterMasks.isEmpty { letterMasks = ["\(letterChar)_mask"] }
            maskAssetNames = letterMasks
            
        case .numbers:
            let number = idx
            let numberImg = UIImage(named: "number_\(number)")
            for i in 0...3 { letterImageViews[i].image = numberImg; letterImageViews[i].tintColor = nil }
            
            boxAssetBaseName = "box_\(number)"
            if let boxImg = UIImage(named: boxAssetBaseName) {
                pane5LetterImageView.image = boxImg; pane6LetterImageView.image = boxImg
            } else {
                pane5LetterImageView.image = numberImg; pane6LetterImageView.image = numberImg
            }
            pane5LetterImageView.tintColor = nil; pane6LetterImageView.tintColor = nil
            
            var numberMasks: [String] = []
            for i in 1...4 {
                let name = "\(number)_mask_\(i)"
                if UIImage(named: name) != nil { numberMasks.append(name) }
            }
            if numberMasks.isEmpty { numberMasks = ["\(number)_mask"] }
            maskAssetNames = numberMasks
        }

        if !committedCanvasViews.isEmpty,
           let savedDrawings = TracingProgressManager.shared.loadSixLetterDrawings(
                index: currentLetterIndex,
                type: contentType
           ),
           savedDrawings.count == committedCanvasViews.count {

            for i in 0..<6 {
                committedCanvasViews[i].drawing = savedDrawings[i]

                if !savedDrawings[i].strokes.isEmpty {
                    paneCompleted[i] = true
                    paneCurrentStrokeIndex[i] = maskAssetNames.count
                } else {
                    paneCompleted[i] = false
                    paneCurrentStrokeIndex[i] = 0
                }
            }

            isTracingLocked = false

        } else {
            for i in 0..<6 {
                committedCanvasViews[i].drawing = PKDrawing()
                paneCurrentStrokeIndex[i] = 0
                paneCompleted[i] = false
            }
            isTracingLocked = false
        }

        if didSetupAfterLayout { loadMasksForAllPanes() }
        resetTransientLayerOnly()
        alphabetCollectionView.reloadData()
    }
    
    private func loadMasksForAllPanes() {
        for i in 0..<6 {
            paneMaskDataArrays[i].removeAll()
            paneMaskSizes[i].removeAll()
            paneMaskOpaqueCounts[i].removeAll()
            
            let names = maskAssetNames
            for name in names {
                if let image = UIImage(named: name),
                   let (bytes, size) = getNormalizedRGBAData(from: image) {
                    
                    paneMaskDataArrays[i].append(bytes)
                    paneMaskSizes[i].append(size)
                    
                    var count = 0
                    for k in stride(from: 3, to: bytes.count, by: 4) {
                        if bytes[k] > alphaThreshold { count += 1 }
                    }
                    paneMaskOpaqueCounts[i].append(count)
                }
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
                handleDeviation()
                return
            }
        }
        
        var didAdvanceAny = false
        var allDone = true
        
        for i in 0..<6 {
            let strokeIdx = paneCurrentStrokeIndex[i]
            let totalStrokes = paneMaskOpaqueCounts[i].count
            
            if strokeIdx < totalStrokes {
                allDone = false
                let totalPixels = paneMaskOpaqueCounts[i][strokeIdx]
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
                if paneCurrentStrokeIndex[i] >= totalStrokes {
                    paneCompleted[i] = true
                    resetTransientLayer(paneIndex: i)
                }
            }
            if didAdvanceAny {
                        saveIntermediateProgress()
                    }
            let fullyComplete = (0..<6).allSatisfy { paneCurrentStrokeIndex[$0] >= maskAssetNames.count }
                    if fullyComplete {
                        onAllStrokesCompleted()

                        let penalty = mistakeCount * 10
                        let accuracy = max(0, 100 - penalty)

                        if accuracy >= 80 {
                            showStickerFromBottom(assetName: "sticker")
                        }

                    }
        }
        
        if !didAdvanceAny && !allDone {
            flashIncompleteWarning()
        }
        
        let fullyComplete = (0..<6).allSatisfy { i in
            paneCurrentStrokeIndex[i] >= maskAssetNames.count
        }
        if fullyComplete {
            onAllStrokesCompleted()
        }
    }
    
    @IBAction func retryTapped(_ sender: UIButton) {
        let completedCount = paneCompleted.filter { $0 }.count

        if completedCount > 0 && completedCount < 6 {
            for i in 0..<6 where !paneCompleted[i] {
                clearPaneCompletely(i)
            }
        } else {
            for i in 0..<6 {
                clearPaneCompletely(i)
            }
        }

        isTracingLocked = false
    }
    
    @IBAction func backTapped(_ sender: UIButton) { goBack() }
    @IBAction func homeTapped(_ sender: UIButton) { goHome() }
    @IBAction func nextChevronTapped(_ sender: Any) { navigateNextLetter() }
    @IBAction func previousChevrontapped(_ sender: UIButton) {
        let targetIndex = currentLetterIndex
        if let nav = navigationController,
           let prevVC = nav.viewControllers.dropLast().last as? TwoLetterTraceViewController,
           prevVC.currentLetterIndex == targetIndex,
           prevVC.contentType == self.contentType {
            nav.popViewController(animated: false)
        } else {
            let vc = storyboard!.instantiateViewController(withIdentifier: "TwoLetterTraceVC") as! TwoLetterTraceViewController
            vc.contentType = contentType
            vc.currentLetterIndex = targetIndex
            navigationController?.pushViewController(vc, animated: false)
        }
    }
    
    @IBAction func speakerButtonTapped(_ sender: UIButton) {
        let textToSpeak = (contentType == .letters) ? String(UnicodeScalar(65 + currentLetterIndex)!) : "\(currentLetterIndex)"
        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
    
    // MARK: - Helpers
    private func calculateFullPageAccuracy(
        touched: Int,
        total: Int
    ) -> CGFloat {
        guard total > 0 else { return 0 }
        return (CGFloat(touched) / CGFloat(total)) * 100
    }

    private func clearPaneCompletely(_ index: Int) {
        resetTransientLayer(paneIndex: index)
        committedCanvasViews[index].drawing = PKDrawing()
        paneCurrentStrokeIndex[index] = 0
        paneCompleted[index] = false
        activePaneIndex = nil
    }

    private func commitTransientAsGreen(paneIndex: Int) {
        let canvas = committedCanvasViews[paneIndex]
        let segments = paneStrokeSegments[paneIndex]
        guard !segments.isEmpty else { return }
        
        var newStrokes: [PKStroke] = canvas.drawing.strokes
        let size = CGSize(width: brushWidth, height: brushWidth)
        let ink = PKInk(.pen, color: .systemGreen)
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
        savePartialProgressIfNeeded()
    }
    
    private func savePartialProgressIfNeeded() {
        let drawings = committedCanvasViews.map { $0.drawing }
        let hasAnyProgress = drawings.contains { !$0.strokes.isEmpty }
        guard hasAnyProgress else { return }

        TracingProgressManager.shared.saveSixLetterDrawings(
            drawings,
            index: currentLetterIndex,
            type: contentType
        )
    }
    
    private func resetTransientLayer(paneIndex: Int) {
        panePaths[paneIndex].removeAllPoints()
        paneShapeLayers[paneIndex].path = nil
        paneShapeLayers[paneIndex].strokeColor = UIColor.white.cgColor
        paneCurrentStrokePoints[paneIndex].removeAll()
        paneTransientTouchedPixels[paneIndex].removeAll()
        paneStrokeSegments[paneIndex].removeAll()
    }
    
    private func resetTransientLayerOnly() {
        for i in 0..<6 { resetTransientLayer(paneIndex: i) }
    }
    
    private func resetFullTrace() {
        TracingProgressManager.shared.deleteSixLetterDrawings(index: currentLetterIndex, type: contentType)
        for i in 0..<6 {
            resetTransientLayer(paneIndex: i)
            committedCanvasViews[i].drawing = PKDrawing()
            paneCurrentStrokeIndex[i] = 0
        }
        isTracingLocked = false
        retryButton.isHidden = false
    }
    
    private func onAllStrokesCompleted() {
            TracingProgressManager.shared.advanceStage(for: currentLetterIndex, contentType: contentType)
        TracingProgressManager.shared.setCurrentActiveLetterIndex(currentLetterIndex + 1)
            alphabetCollectionView.reloadData()
        let drawings = committedCanvasViews.map { $0.drawing }
            TracingProgressManager.shared.saveSixLetterDrawings(drawings, index: currentLetterIndex, type: contentType)
            
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
            saveIntermediateProgress()
            let penalty = mistakeCount * 10
            let performanceScore = max(0, 100 - penalty)
            
            print("Six Letter Session Complete. Total Mistakes: \(mistakeCount) | Final Score: \(performanceScore)")
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
        for i in 0..<6 {
            paneCompleted[i] = true
        }
        isTracingLocked = true
        }
    
    private func navigateNextLetter() {
        let vc = storyboard!.instantiateViewController(withIdentifier: "OneLetterTraceVC") as! OneLetterTraceViewController
        vc.contentType = contentType
        vc.currentLetterIndex = currentLetterIndex + 1
        navigationController?.pushViewController(vc, animated: false)
    }
    
    private func updateNextChevronState() {
        let unlocked = TracingProgressManager.shared.highestUnlockedIndex(for: contentType)
        if currentLetterIndex < unlocked {
            nextChevronButton.isEnabled = true; nextChevronButton.alpha = 1.0
        } else {
            nextChevronButton.isEnabled = false; nextChevronButton.alpha = 0.4
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
    
    @IBAction func letterButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index <= TracingProgressManager.shared.highestUnlockedIndex(for: contentType) else { return }
        let vc = storyboard!.instantiateViewController(withIdentifier: "OneLetterTraceVC") as! OneLetterTraceViewController
        vc.contentType = contentType
        vc.currentLetterIndex = index
        navigationController?.pushViewController(vc, animated: false)
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
