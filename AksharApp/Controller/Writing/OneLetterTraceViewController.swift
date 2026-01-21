//
//  OneLetterTraceViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit
import PencilKit
import AVFoundation

class OneLetterTraceViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, PKCanvasViewDelegate {
    
    // MARK: - Properties
    var contentType: WritingContentType = .letters
    var currentLetterIndex: Int = 0
    
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

    // MARK: - PencilKit & Tracing State
    private var committedCanvasView: PKCanvasView!
    private var currentPath = UIBezierPath()
    private var shapeLayer: CAShapeLayer!
    private var isTracingLocked = false
    private let synthesizer = AVSpeechSynthesizer()
    private var isLetterCompleted = false
    
    // MARK: - Configuration Constants
    private let brushWidth: CGFloat = 50.0
    private let coverageThreshold: CGFloat = 0.30
    private let alphaThreshold: UInt8 = 12
    private let deviationResetDelay: TimeInterval = 0.5
    
    // MARK: - Mask and Stroke Data
    private var maskAssetNames: [String] = ["A_mask"]
    private var letterAssetName = "A"
    
    private var maskDataArrays: [[UInt8]] = []
    private var maskSizes: [CGSize] = []
    private var maskOpaquePixelCount: [Int] = []
    
    private var currentStrokeIndex = 0
    private var transientTouchedPixels = Set<Int>()
    private var currentStrokePoints: [CGPoint] = []
    private var strokeSegments: [[CGPoint]] = []
    private var didSetupAfterLayout = false
    private var mistakeCount = 0
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupUIAppearance()
        setupTracingViews()
        setupPencilKitCanvases()
        
        showLetter(at: currentLetterIndex)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateChevronStates()
        alphabetCollectionView.reloadData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didSetupAfterLayout {
            loadMasks()
            alignCanvasesToLetterImageView()
            didSetupAfterLayout = true
        }
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
    }

    private func setupTracingViews() {
        letterImageView.isUserInteractionEnabled = false
        letterImageView.contentMode = .scaleAspectFit
        committedDrawingImageView.isUserInteractionEnabled = false
        committedDrawingImageView.backgroundColor = .clear
        
        transientDrawingImageView?.image = nil
        transientDrawingImageView?.backgroundColor = .clear
        transientDrawingImageView?.isUserInteractionEnabled = false
        
        shapeLayer = CAShapeLayer()
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.lineWidth = brushWidth
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        shapeLayer.fillColor = UIColor.clear.cgColor
        
        letterImageView.layer.addSublayer(shapeLayer)
        shapeLayer.frame = letterImageView.bounds
    }

    private func setupPencilKitCanvases() {
        committedCanvasView = PKCanvasView(frame: .zero)
        committedCanvasView.backgroundColor = .clear
        committedCanvasView.isOpaque = false
        committedCanvasView.drawing = PKDrawing()
        committedCanvasView.tool = PKInkingTool(.pen, color: UIColor.systemGreen, width: brushWidth)
        committedCanvasView.isUserInteractionEnabled = false
        committedCanvasView.delegate = self
        committedCanvasView.translatesAutoresizingMaskIntoConstraints = false
        
        committedDrawingImageView.addSubview(committedCanvasView)
        
        NSLayoutConstraint.activate([
            committedCanvasView.leadingAnchor.constraint(equalTo: letterImageView.leadingAnchor),
            committedCanvasView.trailingAnchor.constraint(equalTo: letterImageView.trailingAnchor),
            committedCanvasView.topAnchor.constraint(equalTo: letterImageView.topAnchor),
            committedCanvasView.bottomAnchor.constraint(equalTo: letterImageView.bottomAnchor)
        ])
    }

    private func alignCanvasesToLetterImageView() {
        committedCanvasView.setNeedsDisplay()
    }
    
    // MARK: - Scoring & Accuracy Helpers
    private func calculateFullPageAccuracy(
        touched: Int,
        total: Int
    ) -> CGFloat {
        guard total > 0 else { return 0 }
        return (CGFloat(touched) / CGFloat(total)) * 100
    }

    // MARK: - Content Loading & State Restoration
    private func showLetter(at index: Int) {
        currentLetterIndex = index
        maskAssetNames.removeAll()
        letterImageView.image = nil
        letterImageView.tintColor = nil
        let categoryKey = (contentType == .letters) ? "letters" : "numbers"
        mistakeCount = TracingProgressManager.shared.getMistakeCount(index: currentLetterIndex, category: categoryKey)
        switch contentType {
        case .letters:
            letterAssetName = String(UnicodeScalar(65 + index)!)
            if let img = UIImage(named: "letter_\(letterAssetName)") {
                letterImageView.image = img
            } else {
                letterImageView.image = UIImage(named: letterAssetName)
            }
            maskAssetNames = ["\(letterAssetName)_mask"]

        case .numbers:
            letterAssetName = "number_\(index)"
            letterImageView.image = UIImage(named: letterAssetName)
            maskAssetNames = ["\(index)_mask"]
        }
        let savedDrawing = TracingProgressManager.shared
            .loadOneLetterDrawing(index: index, type: contentType)

        committedCanvasView.drawing = savedDrawing ?? PKDrawing()
        isLetterCompleted = savedDrawing != nil
        isTracingLocked = savedDrawing != nil

        loadMasks()
        currentStrokeIndex = 0
        resetTransientLayer()
        alphabetCollectionView.reloadData()
    }
    
    private func loadMasks() {
        maskDataArrays.removeAll()
        maskSizes.removeAll()
        maskOpaquePixelCount.removeAll()

        for name in maskAssetNames {
            guard let image = UIImage(named: name),
                  let (bytes, size) = getNormalizedRGBAData(from: image) else {
                print("Warning: mask '\(name)' not found or invalid.")
                continue
            }
            
            maskDataArrays.append(bytes)
            maskSizes.append(size)
            
            var opaqueCount = 0
            for i in stride(from: 3, to: bytes.count, by: 4) {
                if bytes[i] > alphaThreshold {
                    opaqueCount += 1
                }
            }
            maskOpaquePixelCount.append(opaqueCount)
        }
    }

    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isTracingLocked,
              !isLetterCompleted
        else { return }

        guard let touch = touches.first else { return }
        let location = touch.location(in: letterImageView)
        currentPath.move(to: location)
        currentStrokePoints = [location]
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isTracingLocked,
              !isLetterCompleted
        else { return }

        guard let touch = touches.first, let event = event else { return }

        if let coalesced = event.coalescedTouches(for: touch) {
            for cTouch in coalesced {
                let location = cTouch.location(in: letterImageView)
                currentPath.addLine(to: location)
                currentStrokePoints.append(location)
                validatePoint(location)
            }
        }
        shapeLayer.path = currentPath.cgPath
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isLetterCompleted else { return }
        guard !currentStrokePoints.isEmpty else { return }

        strokeSegments.append(currentStrokePoints)
        currentStrokePoints = []
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetTransientLayer()
    }

    // MARK: - Validation & Tracing Logic
    private func validatePoint(_ point: CGPoint) {
        guard currentStrokeIndex < maskSizes.count else { return }

        let maskSize = maskSizes[currentStrokeIndex]
        let viewSize = letterImageView.bounds.size
        
        let scale = min(viewSize.width / maskSize.width, viewSize.height / maskSize.height)
        let imageDrawSize = CGSize(width: maskSize.width * scale, height: maskSize.height * scale)
        let xOffset = (viewSize.width - imageDrawSize.width) / 2
        let yOffset = (viewSize.height - imageDrawSize.height) / 2

        let px = (point.x - xOffset) / scale
        let py = (point.y - yOffset) / scale
        
        guard px >= 0, py >= 0, px < maskSize.width, py < maskSize.height else { return }

        let imagePoint = CGPoint(x: px, y: py)

        if isMaskPixelOpaque(maskIndex: currentStrokeIndex, atImagePoint: imagePoint, threshold: alphaThreshold) {
            shapeLayer.strokeColor = UIColor.white.cgColor
            
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
                    if dx*dx + dy*dy > brushRadius*brushRadius { continue } // Circular brush
                    
                    let idx = y * w + x
                    transientTouchedPixels.insert(idx)
                }
            }
        } else {
            triggerDeviation()
        }
    }

    private func triggerDeviation() {
        if isTracingLocked { return }
        mistakeCount += 1
        let categoryKey = (contentType == .letters) ? "letters" : "numbers"
        TracingProgressManager.shared.saveMistakeCount(mistakeCount, index: currentLetterIndex, category: categoryKey)
        isTracingLocked = true
        shapeLayer.strokeColor = UIColor.red.cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + deviationResetDelay) {
            self.resetTransientLayer()
            self.isTracingLocked = false
        }
    }
    
    private func resetTransientLayer() {
        currentPath.removeAllPoints()
        shapeLayer.path = nil
        shapeLayer.strokeColor = UIColor.white.cgColor
        currentStrokePoints.removeAll()
        transientTouchedPixels.removeAll()
        strokeSegments.removeAll()
    }
    
    // MARK: - Stroke Commit & Completion
    private func commitTransientAsGreen() {
        guard !strokeSegments.isEmpty else { return }
        var newStrokes: [PKStroke] = committedCanvasView.drawing.strokes

        for segment in strokeSegments {
            guard segment.count > 1 else { continue }
            var pkPoints: [PKStrokePoint] = []
            var time: CGFloat = 0
            let size = CGSize(width: brushWidth, height: brushWidth)

            for pt in segment {
                let sp = PKStrokePoint(location: pt, timeOffset: time, size: size, opacity: 1, force: 1, azimuth: 0, altitude: 0)
                pkPoints.append(sp)
                time += 0.01
            }
            let path = PKStrokePath(controlPoints: pkPoints, creationDate: Date())
            newStrokes.append(PKStroke(ink: PKInk(.pen, color: .systemGreen), path: path))
        }
        committedCanvasView.drawing = PKDrawing(strokes: newStrokes)
        strokeSegments.removeAll()
    }
    
    private func onAllStrokesCompleted() {
        isLetterCompleted = true
        isTracingLocked = true
        resetTransientLayer()
        TracingProgressManager.shared.saveOneLetterDrawing(
            committedCanvasView.drawing,
            index: currentLetterIndex,
            type: contentType
        )
        
        nextChevronButton.isEnabled = true
        nextChevronButton.alpha = 1.0
        view.bringSubviewToFront(nextChevronButton)
        let penalty = mistakeCount * 10
                let performanceScore = max(0, 100 - penalty)
                
                print("Final Score Saved: \(performanceScore)% (Mistakes: \(mistakeCount))")
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

    // MARK: - Actions
    @IBAction func backTapped(_ sender: UIButton) {
        goBack()
    }
    
    @IBAction func homeTapped(_ sender: UIButton) {
        goHome()
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
        if isTracingLocked { return }

        guard currentStrokeIndex < maskOpaquePixelCount.count else { return }
        let totalOpaque = maskOpaquePixelCount[currentStrokeIndex]
        if totalOpaque == 0 {
            currentStrokeIndex += 1
            return
        }

        let coverageRatio = CGFloat(transientTouchedPixels.count) / CGFloat(totalOpaque)
        print("Coverage: \(Int(coverageRatio * 100))% (Required: \(Int(coverageThreshold * 100))%)")

        if coverageRatio >= coverageThreshold {
            commitTransientAsGreen()
            currentStrokeIndex += 1
            resetTransientLayer()
            
            if currentStrokeIndex >= maskAssetNames.count {
                onAllStrokesCompleted()
                let penalty = mistakeCount * 10
                let accuracy = max(0, 100 - penalty)

                if accuracy >= 80 {
                    showStickerFromBottom(assetName: "sticker")
                }

            }
        } else {
            flashIncompleteWarning()
        }
    }
    
    @IBAction func speakerButtonTapped(_ sender: UIButton) {
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
    
    @IBAction func retryTapped(_ sender: UIButton) {
        TracingProgressManager.shared.deleteOneLetterDrawing(
            index: currentLetterIndex,
            type: contentType
        )

        isLetterCompleted = false
        isTracingLocked = false

        resetTransientLayer()
        committedCanvasView.drawing = PKDrawing()
        currentStrokeIndex = 0
        shapeLayer.strokeColor = UIColor.white.cgColor
    }
    
    @IBAction func nextChevronTapped(_ sender: UIButton) {
        navigateNext()
    }
    
    @IBAction func previousChevronTapped(_ sender: UIButton) {
        guard currentLetterIndex > 0 else { return }
        
        let targetIndex = currentLetterIndex - 1
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

    // MARK: - Navigation Helpers
    private func navigateNext() {
        let vc = storyboard!.instantiateViewController(withIdentifier: "TwoLetterTraceVC") as! TwoLetterTraceViewController
        vc.contentType = contentType
        vc.currentLetterIndex = currentLetterIndex
        navigationController?.pushViewController(vc, animated: false)
    }
    
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
    
    // MARK: - UI Feedback & Animations
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
    
    // MARK: - Image & Mask Utilities
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
    
    private func isMaskPixelOpaque(maskIndex: Int, atImagePoint point: CGPoint, threshold: UInt8) -> Bool {
        guard maskIndex < maskDataArrays.count else { return false }
        let bytes = maskDataArrays[maskIndex]
        let size = maskSizes[maskIndex]
        let width = Int(size.width)
        let height = Int(size.height)
        let x = Int(point.x)
        let y = Int(point.y)
        
        if x < 0 || x >= width || y < 0 || y >= height { return false }
        let pixelIndex = (y * width + x) * 4
        if pixelIndex + 3 >= bytes.count { return false }
        
        return bytes[pixelIndex + 3] > threshold
    }
    
    private func resetFullTrace() {
        TracingProgressManager.shared.deleteOneLetterDrawing(index: currentLetterIndex, type: contentType)
        resetTransientLayer()
        committedCanvasView.drawing = PKDrawing()
        isTracingLocked = false
        currentStrokeIndex = 0
        shapeLayer.strokeColor = UIColor.white.cgColor
    }
    
    private func updateChevronStates() {
        let unlocked = TracingProgressManager.shared.highestUnlockedIndex(for: contentType)

        if currentLetterIndex < unlocked {
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
        } else if currentLetterIndex == unlocked {
            if TracingProgressManager.shared.loadOneLetterDrawing(index: currentLetterIndex, type: contentType) != nil {
                nextChevronButton.isEnabled = true
                nextChevronButton.alpha = 1.0
            } else {
                nextChevronButton.isEnabled = false
                nextChevronButton.alpha = 0.4
            }
        } else {
            nextChevronButton.isEnabled = false
            nextChevronButton.alpha = 0.4
        }

        if currentLetterIndex > 0 {
            backChevronButton.isEnabled = true
            backChevronButton.alpha = 1.0
        } else {
            backChevronButton.isEnabled = false
            backChevronButton.alpha = 0.4
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

        let unlockedIndex = TracingProgressManager.shared.highestUnlockedIndex(for: contentType)
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
