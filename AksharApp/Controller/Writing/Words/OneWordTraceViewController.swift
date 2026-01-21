//
//  OneWordTraceViewController.swift
//  AksharApp
//
//  Created by AksharApp on 14/01/26.
//

import UIKit
import PencilKit
import AVFoundation

class OneWordTraceViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, PKCanvasViewDelegate {
    
    // MARK: - Properties
    var selectedCategory: TracingCategory = .threeLetter
    var currentWordIndex: Int = 0
    private var analyticsSessionID: UUID!
    private var powerWordCenterConstraints: [NSLayoutConstraint] = []
    
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
    
    // MARK: - PencilKit & Tracing State
    private var committedCanvasView: PKCanvasView!
    private var currentPath = UIBezierPath()
    private var shapeLayer: CAShapeLayer!
    private var isTracingLocked = false
    private let synthesizer = AVSpeechSynthesizer()
    private var isWordCompleted = false
    private var mistakeCount = 0
    private var words: [TracingWord] = []
    
    // MARK: - Configuration Constants
    private var brushWidth: CGFloat {
        switch selectedCategory {
        case .threeLetter: return 40.0
        case .fourLetter: return 45.0
        case .fiveLetter: return 30.0
        case .sixLetter: return 25.0
        default: return 40.0
        }
    }
    private let coverageThreshold: CGFloat = 0.70
    private let alphaThreshold: UInt8 = 12
    private let deviationResetDelay: TimeInterval = 0.5
    
    // MARK: - Data Models
    private var maskDataArrays: [[UInt8]] = []
    private var maskSizes: [CGSize] = []
    private var maskOpaquePixelCount: [Int] = []
    
    private var currentStrokeIndex = 0
    private var transientTouchedPixels = Set<Int>()
    private var currentStrokePoints: [CGPoint] = []
    private var strokeSegments: [[CGPoint]] = []
    private var didSetupAfterLayout = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTracingViews()
        setupPencilKitCanvases()
        TracingProgressManager.shared.setActiveWord(
            index: currentWordIndex,
            category: selectedCategory.rawValue
        )
        
        if !didSetupAfterLayout {
            loadMasks()
            alignCanvasesToImageView()
            applyPowerWordLayoutIfNeeded()
            didSetupAfterLayout = true
        }
        
        if let savedID = TracingProgressManager.shared.getSessionID(index: currentWordIndex, category: selectedCategory.rawValue) {
            analyticsSessionID = savedID
        } else {
            analyticsSessionID = UUID()
            TracingProgressManager.shared.saveSessionID(analyticsSessionID, index: currentWordIndex, category: selectedCategory.rawValue)
        }
        
        let allWords = TracingWordLoader.loadWords()
        words = allWords.words(for: selectedCategory.rawValue)
        
        showWord(at: currentWordIndex)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showWord(at: currentWordIndex)
        updateChevronStates()
        wordsCollectionView.reloadData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didSetupAfterLayout {
            loadMasks()
            alignCanvasesToImageView()
            didSetupAfterLayout = true
        }
    }
    
    // MARK: - Setup Methods
    private func applyPowerWordLayoutIfNeeded() {
        guard selectedCategory == .power else { return }
        illustrationImageView.isHidden = true
        wordImageView.translatesAutoresizingMaskIntoConstraints = false
        let constraintsToDeactivate = yellowView.constraints.filter {
            $0.firstItem as? UIView == wordImageView ||
            $0.secondItem as? UIView == wordImageView
        }
        NSLayoutConstraint.deactivate(constraintsToDeactivate)
        let centerX = wordImageView.centerXAnchor.constraint(equalTo: yellowView.centerXAnchor)
        let centerY = wordImageView.centerYAnchor.constraint(equalTo: yellowView.centerYAnchor)
        let maxWidth = wordImageView.widthAnchor.constraint(
            lessThanOrEqualTo: yellowView.widthAnchor,
            multiplier: 0.85
        )
        let maxHeight = wordImageView.heightAnchor.constraint(
            lessThanOrEqualTo: yellowView.heightAnchor,
            multiplier: 0.6
        )
        powerWordCenterConstraints = [centerX, centerY, maxWidth, maxHeight]
        NSLayoutConstraint.activate(powerWordCenterConstraints)
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
        
        let brown = UIColor(red: 135/255.0, green: 87/255.0, blue: 55/255.0, alpha: 1.0)
        let yellow = UIColor(red: 248/255.0, green: 236/255.0, blue: 180/255.0, alpha: 1.0)
        
        style(speakerButton, border: brown.cgColor)
        style(retryButton, border: brown.cgColor)
        style(tickButton, border: brown.cgColor)
        
        yellowView.layer.cornerRadius = 25
        
        wordsCollectionView.layer.borderColor = yellow.cgColor
        wordsCollectionView.layer.borderWidth = 2
        wordsCollectionView.layer.cornerRadius = 20
        
        illustrationImageView.layer.cornerRadius = 15
        illustrationImageView.clipsToBounds = true
        illustrationImageView.contentMode = .scaleAspectFit
        
        wordImageView.isUserInteractionEnabled = false
        wordImageView.contentMode = .scaleAspectFit
        
        committedDrawingImageView.isUserInteractionEnabled = false
        committedDrawingImageView.backgroundColor = .clear
        
        nextChevronButton.isEnabled = false
        nextChevronButton.alpha = 0.4
    }
    
    private func style(_ view: UIView, border: CGColor, width: CGFloat = 3) {
        view.layer.borderColor = border
        view.layer.borderWidth = width
    }
    
    private func setupSpeakerTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(speakerTapped))
        speakerButton.addGestureRecognizer(tap)
        speakerButton.isUserInteractionEnabled = true
    }

    private func setupTracingViews() {
        shapeLayer = CAShapeLayer()
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.lineWidth = brushWidth
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        shapeLayer.fillColor = UIColor.clear.cgColor
        
        wordImageView.layer.addSublayer(shapeLayer)
        shapeLayer.frame = wordImageView.bounds
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
            committedCanvasView.leadingAnchor.constraint(equalTo: wordImageView.leadingAnchor),
            committedCanvasView.trailingAnchor.constraint(equalTo: wordImageView.trailingAnchor),
            committedCanvasView.topAnchor.constraint(equalTo: wordImageView.topAnchor),
            committedCanvasView.bottomAnchor.constraint(equalTo: wordImageView.bottomAnchor)
        ])
    }
    
    private func alignCanvasesToImageView() {
        committedCanvasView.setNeedsDisplay()
        shapeLayer.frame = wordImageView.bounds
    }

    // MARK: - Logic & Content Loading
    private func showWord(at index: Int) {
        guard index < words.count else { return }
        currentWordIndex = index
        
        mistakeCount = TracingProgressManager.shared.getMistakeCount(index: index, category: selectedCategory.rawValue)
        
        let word = words[index]
        if let image = UIImage(named: word.wordImageName) {
            wordImageView.image = image
        }
        
        if let imgName = word.imageName, let illustration = UIImage(named: imgName) {
            illustrationImageView.image = illustration
        } else {
            illustrationImageView.image = nil
        }
        loadMasks()
        
        if let savedDrawing = TracingProgressManager.shared.loadOneWordDrawing(index: index, category: selectedCategory.rawValue) {
            committedCanvasView.drawing = savedDrawing
            
            let unlockedIdx = TracingProgressManager.shared.highestUnlockedWordIndex(for: selectedCategory.rawValue)
            let isHistoricallyDone = index < unlockedIdx
            let hasContent = !savedDrawing.strokes.isEmpty
            
            if isHistoricallyDone && hasContent {
                isWordCompleted = true
                isTracingLocked = true
                tickButton.backgroundColor = .systemGreen
                currentStrokeIndex = maskDataArrays.count
            }
            else {
                isWordCompleted = false
                isTracingLocked = false
                tickButton.backgroundColor = .white
                if !hasContent {
                    currentStrokeIndex = 0
                }
            }
        } else {
            committedCanvasView.drawing = PKDrawing()
            isWordCompleted = false
            isTracingLocked = false
            tickButton.backgroundColor = .white
            currentStrokeIndex = 0
        }
        
        resetTransientLayer()
        updateChevronStates()
        wordsCollectionView.reloadData()
    }
    
    private func loadMasks() {
        guard currentWordIndex < words.count else { return }
        maskDataArrays.removeAll()
        maskSizes.removeAll()
        maskOpaquePixelCount.removeAll()
        
        let wordName = words[currentWordIndex].wordImageName
        let maskName = "\(wordName)_mask"
        
        guard let image = UIImage(named: maskName),
              let (bytes, size) = getNormalizedRGBAData(from: image) else {
            return
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

    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isTracingLocked,
              !isWordCompleted
        else { return }

        guard let touch = touches.first else { return }
        let location = touch.location(in: wordImageView)
        currentPath.move(to: location)
        currentStrokePoints = [location]
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isTracingLocked,
              !isWordCompleted
        else { return }

        guard let touch = touches.first, let event = event else { return }

        if let coalesced = event.coalescedTouches(for: touch) {
            for cTouch in coalesced {
                let location = cTouch.location(in: wordImageView)
                currentPath.addLine(to: location)
                currentStrokePoints.append(location)
                validatePoint(location)
            }
        }
        shapeLayer.path = currentPath.cgPath
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isWordCompleted else { return }
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
        let viewSize = wordImageView.bounds.size
        
        let scale = min(viewSize.width / maskSize.width, viewSize.height / maskSize.height)
        let imageDrawSize = CGSize(width: maskSize.width * scale, height: maskSize.height * scale)
        let xOffset = (viewSize.width - imageDrawSize.width) / 2
        let yOffset = (viewSize.height - imageDrawSize.height) / 2

        let px = (point.x - xOffset) / scale
        let py = (point.y - yOffset) / scale
        
        guard px >= 0, py >= 0, px < maskSize.width, py < maskSize.height else { return }

        let imagePoint = CGPoint(x: px, y: py)

        if isMaskPixelOpaque(maskIndex: currentStrokeIndex, atImagePoint: imagePoint) {
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
        TracingProgressManager.shared.saveMistakeCount(mistakeCount, index: currentWordIndex, category: selectedCategory.rawValue)
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
    
    // MARK: - Progress & Completion
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
        isWordCompleted = true
        isTracingLocked = true
        resetTransientLayer()
        tickButton.backgroundColor = .systemGreen
        
        TracingProgressManager.shared.saveOneWordDrawing(
            committedCanvasView.drawing,
            index: currentWordIndex,
            category: selectedCategory.rawValue
        )
        
        saveIntermediateProgress()
        TracingProgressManager.shared.saveMistakeCount(0, index: currentWordIndex, category: selectedCategory.rawValue)
        TracingProgressManager.shared.deleteSessionID(index: currentWordIndex, category: selectedCategory.rawValue)
        
        nextChevronButton.isEnabled = true
        nextChevronButton.alpha = 1.0
        
        let penalty = mistakeCount * 10
        let performanceScore = max(0, 100 - penalty)
        
        let session = WritingSessionData(
            id: UUID(),
            date: Date(),
            childId: "default_child",
            lettersAccuracy: 0,
            wordsAccuracy: performanceScore,
            numbersAccuracy: 0
        )
        AnalyticsStore.shared.appendWritingSession(session)
        TracingProgressManager.shared.saveMistakeCount(0, index: currentWordIndex, category: selectedCategory.rawValue)
    }

    // MARK: - Actions
    @IBAction func backTapped(_ sender: UIButton) {
        if currentWordIndex > 0 {
            let vc = storyboard!.instantiateViewController(withIdentifier: "SixWordTraceVC") as! SixWordTraceViewController
            vc.currentWordIndex = currentWordIndex - 1
            vc.selectedCategory = selectedCategory
            navigationController?.pushViewController(vc, animated: false)
        }
    }
    
    @IBAction func homeButtonTapped(_ sender: UIButton) {
        navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func backButtonTapped(_ sender: Any) {
        navigationController?.popToViewController(
            navigationController!.viewControllers.first {
                $0 is WordsCategoriesViewController
            }!,
            animated: true
        )
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
        
        if coverageRatio >= coverageThreshold {
            commitTransientAsGreen()
            currentStrokeIndex += 1
            resetTransientLayer()
            
            saveIntermediateProgress()
            
            if currentStrokeIndex >= maskDataArrays.count {
                onAllStrokesCompleted()
                let penalty = mistakeCount * 10
                let accuracy = max(0, 100 - penalty)
                print(accuracy)

                if accuracy >= 80 {
                    showStickerFromBottom(assetName: "sticker")
                }
            }
        } else {
            flashIncompleteWarning()
        }
    }
    
    @IBAction func speakerTapped(_ sender: UIButton) {
        guard currentWordIndex < words.count else { return }
        guard currentWordIndex < words.count else { return }
        let textToSpeak = words[currentWordIndex].word
        
        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
    
    @IBAction func retryButtonTapped(_ sender: UIButton) {
        TracingProgressManager.shared.deleteOneWordDrawing(
            index: currentWordIndex,
            category: selectedCategory.rawValue
        )

        isWordCompleted = false
        isTracingLocked = false
        currentStrokeIndex = 0

        resetTransientLayer()
        committedCanvasView.drawing = PKDrawing()
        shapeLayer.strokeColor = UIColor.white.cgColor
        tickButton.backgroundColor = .white
        updateChevronStates()
    }
    
    @IBAction func nextChevronTapped(_ sender: UIButton) {
        navigateNext()
    }

    // MARK: - Navigation Helpers
    private func navigateNext() {
        let vc = storyboard!.instantiateViewController(withIdentifier: "TwoWordTraceVC") as! TwoWordTraceViewController
        vc.currentWordIndex = currentWordIndex
        vc.selectedCategory = selectedCategory
        navigationController?.pushViewController(vc, animated: false)
    }
    
    private func updateChevronStates() {
        let unlocked = TracingProgressManager.shared.highestUnlockedWordIndex(for: selectedCategory.rawValue)

        if currentWordIndex < unlocked {
            nextChevronButton.isEnabled = true
            nextChevronButton.alpha = 1.0
        } else if currentWordIndex == unlocked {
            if TracingProgressManager.shared.loadOneWordDrawing(index: currentWordIndex, category: selectedCategory.rawValue) != nil {
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
        
        if currentWordIndex > 0 {
            backChevronButton.isEnabled = true
            backChevronButton.alpha = 1.0
        } else {
            backChevronButton.isEnabled = false
            backChevronButton.alpha = 0.4
        }
    }

    // MARK: - Helpers
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
    
    private func isMaskPixelOpaque(maskIndex: Int, atImagePoint point: CGPoint) -> Bool {
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
        
        return bytes[pixelIndex + 3] > alphaThreshold
    }

    // MARK: - CollectionView DataSource & Delegate
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return words.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "wordButtonCell", for: indexPath)
        
        if let button = cell.viewWithTag(100) as? UIButton ?? cell.contentView.subviews.first(where: { $0 is UIButton }) as? UIButton {
            let word = words[indexPath.item].word
            
            button.configuration = nil
            button.setTitle(word, for: .normal)
            
            let unlockedIdx = TracingProgressManager.shared.highestUnlockedWordIndex(for: selectedCategory.rawValue)
            let isUnlocked = indexPath.item <= unlockedIdx
            let isCompleted = indexPath.item < unlockedIdx
            
            button.titleLabel?.font = UIFont.systemFont(ofSize: 30, weight: .medium)
            
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
            showWord(at: indexPath.item)
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
