//
//  BaseTraceViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit
import PencilKit
import AVFoundation

class BaseTraceViewController: UIViewController {

    // MARK: - Configuration Properties
    var contentType: WritingContentType = .letters
    var currentIndex: Int = 0
    // Computed property to be overridden or used as is
    var categoryKey: String { contentType == .letters ? "letters" : "numbers" }
    
    var brushWidth: CGFloat = 30.0
    var coverageThreshold: CGFloat = 0.30
    
    // MARK: - State
    var mistakeCount = 0
    var isTracingLocked = false
    let synthesizer = AVSpeechSynthesizer()
    
    // MARK: - Pane Data Collections
    var paneLetterImageViews: [UIImageView] = []
    var paneCommittedCanvases: [PKCanvasView] = []
    
    // Internal Pane State
    var paneShapeLayers: [CAShapeLayer] = []
    var panePaths: [UIBezierPath] = []
    
    // FIX 1: Store multiple segments (strokes) per pane [PaneIndex][SegmentIndex][Points]
    var paneStrokeSegments: [[[CGPoint]]] = []
    
    var paneCurrentStrokePoints: [[CGPoint]] = []
    var paneTransientTouchedPixels: [Set<Int>] = []
    var paneCurrentMaskIndex: [Int] = []
    var paneIsCompleted: [Bool] = []
    
    // Mask Data
    var paneMaskData: [[[UInt8]]] = []
    var paneMaskSizes: [[CGSize]] = []
    var paneMaskOpaqueCounts: [[Int]] = []
    var paneMaskAssetNames: [String] = []

    // Interaction State
    var activePaneIndex: Int? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Setup Helpers
    func initPaneArrays(count: Int) {
        paneShapeLayers = []
        panePaths = []
        paneCurrentStrokePoints = Array(repeating: [], count: count)
        paneStrokeSegments = Array(repeating: [], count: count) // Initialize segments array
        paneTransientTouchedPixels = Array(repeating: Set<Int>(), count: count)
        paneCurrentMaskIndex = Array(repeating: 0, count: count)
        paneIsCompleted = Array(repeating: false, count: count)
        
        paneMaskData = Array(repeating: [], count: count)
        paneMaskSizes = Array(repeating: [], count: count)
        paneMaskOpaqueCounts = Array(repeating: [], count: count)
    }

    func setupShapeLayer(for view: UIImageView) {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = brushWidth
        layer.lineCap = .round
        layer.lineJoin = .round
        layer.fillColor = UIColor.clear.cgColor
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        paneShapeLayers.append(layer)
        panePaths.append(UIBezierPath())
    }
    
    func setupCanvas(in wrapperView: UIView) -> PKCanvasView {
        let canvas = PKCanvasView(frame: .zero)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: UIColor.systemGreen, width: brushWidth)
        canvas.isUserInteractionEnabled = false
        canvas.translatesAutoresizingMaskIntoConstraints = false
        wrapperView.addSubview(canvas)
        NSLayoutConstraint.activate([
            canvas.leadingAnchor.constraint(equalTo: wrapperView.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: wrapperView.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: wrapperView.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor)
        ])
        return canvas
    }

    // MARK: - Mask Loading Logic
    func loadMasks(forPane paneIndex: Int, assetNames: [String]) {
        guard paneIndex < paneMaskData.count else { return }
        paneMaskData[paneIndex].removeAll()
        paneMaskSizes[paneIndex].removeAll()
        paneMaskOpaqueCounts[paneIndex].removeAll()
        
        for name in assetNames {
            if let image = UIImage(named: name),
               let (bytes, size) = TraceValidator.getNormalizedRGBAData(from: image) {
                
                paneMaskData[paneIndex].append(bytes)
                paneMaskSizes[paneIndex].append(size)
                
                var count = 0
                for k in stride(from: 3, to: bytes.count, by: 4) {
                    if bytes[k] > TraceValidator.alphaThreshold { count += 1 }
                }
                paneMaskOpaqueCounts[paneIndex].append(count)
            }
        }
    }

    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isTracingLocked { return }
        guard let touch = touches.first else { return }
        
        activePaneIndex = nil
        
        for (i, imageView) in paneLetterImageViews.enumerated() {
            if paneIsCompleted[i] { continue }
            
            let loc = touch.location(in: imageView)
            if imageView.bounds.contains(loc) {
                activePaneIndex = i
                panePaths[i].move(to: loc)
                paneCurrentStrokePoints[i] = [loc] // Start new stroke
                
                validatePoint(loc, paneIndex: i)
                break
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isTracingLocked { return }
        guard let idx = activePaneIndex, let touch = touches.first, let event = event else { return }
        
        if let coalesced = event.coalescedTouches(for: touch) {
            for cTouch in coalesced {
                let loc = cTouch.location(in: paneLetterImageViews[idx])
                panePaths[idx].addLine(to: loc)
                paneCurrentStrokePoints[idx].append(loc) // Add points to current stroke
                validatePoint(loc, paneIndex: idx)
                if isTracingLocked { break }
            }
        }
        paneShapeLayers[idx].path = panePaths[idx].cgPath
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // FIX 2: When user lifts finger, save the stroke segment
        if let idx = activePaneIndex {
            if !paneCurrentStrokePoints[idx].isEmpty {
                paneStrokeSegments[idx].append(paneCurrentStrokePoints[idx])
            }
            paneCurrentStrokePoints[idx].removeAll()
        }
        activePaneIndex = nil
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let idx = activePaneIndex {
            resetTransientLayer(paneIndex: idx)
        }
        activePaneIndex = nil
    }

    // MARK: - Validation
    func validatePoint(_ point: CGPoint, paneIndex: Int) {
        let strokeIdx = paneCurrentMaskIndex[paneIndex]
        guard strokeIdx < paneMaskSizes[paneIndex].count else { return }
        
        let maskData = paneMaskData[paneIndex][strokeIdx]
        let maskSize = paneMaskSizes[paneIndex][strokeIdx]
        let imageView = paneLetterImageViews[paneIndex]
        
        if TraceValidator.isPointValid(point: point, inImageView: imageView, maskData: maskData, maskSize: maskSize) {
            paneShapeLayers[paneIndex].strokeColor = UIColor.white.cgColor
            
            let pixels = TraceValidator.getTouchedPixels(point: point, inImageView: imageView, maskSize: maskSize, brushWidth: brushWidth)
            for p in pixels {
                paneTransientTouchedPixels[paneIndex].insert(p)
            }
        } else {
            triggerDeviation(paneIndex: paneIndex)
        }
    }
    
    func triggerDeviation(paneIndex: Int) {
        if isTracingLocked { return }
        
        mistakeCount += 1
        WritingGameplayManager.shared.saveMistakeCount(mistakeCount, index: currentIndex, category: categoryKey)
        
        isTracingLocked = true
        paneShapeLayers[paneIndex].strokeColor = UIColor.red.cgColor
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.resetTransientLayer(paneIndex: paneIndex)
            self.isTracingLocked = false
        }
    }
    
    // MARK: - Reset Helpers
    func resetTransientLayer(paneIndex: Int) {
        panePaths[paneIndex].removeAllPoints()
        paneShapeLayers[paneIndex].path = nil
        paneShapeLayers[paneIndex].strokeColor = UIColor.white.cgColor
        paneCurrentStrokePoints[paneIndex].removeAll()
        paneStrokeSegments[paneIndex].removeAll() // FIX 3: Clear stored segments
        paneTransientTouchedPixels[paneIndex].removeAll()
    }
    
    // MARK: - Green Ink Commit Logic
    func checkAndCommitGreenInk(paneIndex: Int) -> Bool {
        let strokeIdx = paneCurrentMaskIndex[paneIndex]
        guard strokeIdx < paneMaskOpaqueCounts[paneIndex].count else { return false }
        
        // Ensure any currently active touch is saved before checking
        if !paneCurrentStrokePoints[paneIndex].isEmpty {
             paneStrokeSegments[paneIndex].append(paneCurrentStrokePoints[paneIndex])
             paneCurrentStrokePoints[paneIndex].removeAll()
        }

        let totalPixels = paneMaskOpaqueCounts[paneIndex][strokeIdx]
        
        // Auto-advance if empty mask (placeholder)
        if totalPixels == 0 {
            paneCurrentMaskIndex[paneIndex] += 1
            return true
        }
        
        let touchedCount = paneTransientTouchedPixels[paneIndex].count
        let ratio = CGFloat(touchedCount) / CGFloat(totalPixels)
        
        if ratio >= coverageThreshold {
            // Success! Convert ALL accumulated strokes to green
            addGreenStrokeToCanvas(paneIndex: paneIndex)
            
            paneCurrentMaskIndex[paneIndex] += 1
            resetTransientLayer(paneIndex: paneIndex)
            
            if paneCurrentMaskIndex[paneIndex] >= paneMaskData[paneIndex].count {
                paneIsCompleted[paneIndex] = true
            }
            return true
        }
        return false
    }
    
    func addGreenStrokeToCanvas(paneIndex: Int) {
        let canvas = paneCommittedCanvases[paneIndex]
        var newStrokes = canvas.drawing.strokes
        let ink = PKInk(.pen, color: .systemGreen)
        let size = CGSize(width: brushWidth, height: brushWidth)
        
        // FIX 4: Loop through ALL accumulated segments
        for segment in paneStrokeSegments[paneIndex] {
            guard segment.count > 1 else { continue }
            
            var pkPoints: [PKStrokePoint] = []
            var time: TimeInterval = 0
            
            for pt in segment {
                pkPoints.append(PKStrokePoint(location: pt, timeOffset: time, size: size, opacity: 1, force: 1, azimuth: 0, altitude: 0))
                time += 0.01
            }
            
            let path = PKStrokePath(controlPoints: pkPoints, creationDate: Date())
            newStrokes.append(PKStroke(ink: ink, path: path))
        }
        
        canvas.drawing = PKDrawing(strokes: newStrokes)
    }
}
