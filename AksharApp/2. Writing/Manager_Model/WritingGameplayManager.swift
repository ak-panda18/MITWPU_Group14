import Foundation
import PencilKit
import UIKit

// MARK: - The State Model (Clean JSON)
struct WritingProgressState: Codable {
    var unlockedIndices: [String: Int] = [:]   // Highest unlocked index
    var mistakeCounts: [String: Int] = [:]     // Analytics
    var lastActiveCategory: String = "3-letter" // For Dashboard
}

final class WritingGameplayManager {
    static let shared = WritingGameplayManager()
    
    private let progressFileName = "writing_progress.json"
    private var state: WritingProgressState = WritingProgressState()
    
    private init() {
        loadProgress()
    }
    
    // MARK: - Public Properties
    var lastActiveCategory: String {
        get { state.lastActiveCategory }
        set {
            state.lastActiveCategory = newValue
            saveProgress()
        }
    }
    
    // MARK: - Progress & Unlocking
    
    func getHighestUnlockedIndex(category: String) -> Int {
        return state.unlockedIndices[category] ?? 0
    }
    
    func unlockNextItem(category: String, currentIndex: Int) {
        let currentMax = getHighestUnlockedIndex(category: category)
        if currentIndex >= currentMax {
            state.unlockedIndices[category] = currentIndex + 1
            saveProgress()
        }
    }
    
    // MARK: - Mistakes (Analytics)
    
    func getMistakeCount(index: Int, category: String) -> Int {
        return state.mistakeCounts["\(category)_\(index)"] ?? 0
    }
    
    func saveMistakeCount(_ count: Int, index: Int, category: String) {
        state.mistakeCounts["\(category)_\(index)"] = count
        saveProgress()
    }
    
    // MARK: - Drawing Management
    
    private func getDrawingURL(index: Int, category: String, stage: String, part: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeCat = category.replacingOccurrences(of: " ", with: "_")
        let filename = "trace_\(safeCat)_\(index)_\(stage)_\(part).data"
        return docs.appendingPathComponent(filename)
    }
    
    // --- Generic Save/Load ---
    func saveDrawing(_ drawing: PKDrawing, index: Int, category: String, stage: String, part: String = "main") {
        let url = getDrawingURL(index: index, category: category, stage: stage, part: part)
        try? drawing.dataRepresentation().write(to: url)
    }
    
    func loadDrawing(index: Int, category: String, stage: String, part: String = "main") -> PKDrawing? {
        let url = getDrawingURL(index: index, category: category, stage: stage, part: part)
        if let data = try? Data(contentsOf: url), let drawing = try? PKDrawing(data: data) {
            return drawing
        }
        return nil
    }
    
    func deleteDrawing(index: Int, category: String, stage: String, part: String = "main") {
        let url = getDrawingURL(index: index, category: category, stage: stage, part: part)
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Specific Stage Helpers
    
    // 1. One Word/Letter
    func saveOneDrawing(_ drawing: PKDrawing, index: Int, category: String) {
        saveDrawing(drawing, index: index, category: category, stage: "one")
        // NOTE: We do NOT unlock the next item here. The user must finish all 3 stages.
    }
    
    func loadOneDrawing(index: Int, category: String) -> PKDrawing? {
        return loadDrawing(index: index, category: category, stage: "one")
    }
    
    func deleteOneDrawing(index: Int, category: String) {
        deleteDrawing(index: index, category: category, stage: "one")
    }
    
    // 2. Two Word/Letter
    func saveTwoDrawings(top: PKDrawing, bottom: PKDrawing, index: Int, category: String) {
        saveDrawing(top, index: index, category: category, stage: "two", part: "top")
        saveDrawing(bottom, index: index, category: category, stage: "two", part: "bottom")
    }
    
    func loadTwoDrawings(index: Int, category: String) -> (PKDrawing, PKDrawing)? {
        guard let top = loadDrawing(index: index, category: category, stage: "two", part: "top"),
              let bottom = loadDrawing(index: index, category: category, stage: "two", part: "bottom") else {
            return nil
        }
        return (top, bottom)
    }
    
    func deleteTwoDrawings(index: Int, category: String) {
        deleteDrawing(index: index, category: category, stage: "two", part: "top")
        deleteDrawing(index: index, category: category, stage: "two", part: "bottom")
    }
    
    // 3. Six Word/Letter
    func saveSixDrawings(_ drawings: [PKDrawing], index: Int, category: String) {
        for (i, d) in drawings.enumerated() {
            saveDrawing(d, index: index, category: category, stage: "six", part: "\(i)")
        }
        // Finishing the 6-word stage unlocks the NEXT word/letter in the sequence
        unlockNextItem(category: category, currentIndex: index)
    }
    
    func loadSixDrawings(index: Int, category: String) -> [PKDrawing]? {
        var result: [PKDrawing] = []
        for i in 0..<6 {
            if let d = loadDrawing(index: index, category: category, stage: "six", part: "\(i)") {
                result.append(d)
            } else {
                return nil
            }
        }
        return result
    }
    
    func deleteSixDrawings(index: Int, category: String) {
        for i in 0..<6 {
            deleteDrawing(index: index, category: category, stage: "six", part: "\(i)")
        }
    }
    
    // MARK: - Internal Helpers
    private func saveProgress() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(progressFileName)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: url)
        }
    }
    
    private func loadProgress() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(progressFileName)
        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode(WritingProgressState.self, from: data) {
            self.state = saved
        }
    }
    
    // MARK: - Navigation Decision Logic
    func getNextViewController(for category: String, index: Int, contentType: WritingContentType? = nil, selectedWordCategory: TracingCategory? = nil) -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        // Stage 3 Check: If 2 drawings are already saved, move to the 6-pane stage
        if loadTwoDrawings(index: index, category: category) != nil {
            if let wordCat = selectedWordCategory {
                let vc = storyboard.instantiateViewController(withIdentifier: "SixWordTraceVC") as! SixWordTraceViewController
                vc.currentWordIndex = index
                vc.selectedCategory = wordCat
                return vc
            } else {
                let vc = storyboard.instantiateViewController(withIdentifier: "SixLetterTraceVC") as! SixLetterTraceViewController
                vc.contentType = contentType ?? .letters
                vc.currentIndex = index // Use base property directly
                return vc
            }
        }
        // Stage 2 Check: If 1 drawing is already saved, move to the 2-pane stage
        else if loadOneDrawing(index: index, category: category) != nil {
            if let wordCat = selectedWordCategory {
                let vc = storyboard.instantiateViewController(withIdentifier: "TwoWordTraceVC") as! TwoWordTraceViewController
                vc.currentWordIndex = index
                vc.selectedCategory = wordCat
                return vc
            } else {
                let vc = storyboard.instantiateViewController(withIdentifier: "TwoLetterTraceVC") as! TwoLetterTraceViewController
                vc.contentType = contentType ?? .letters
                vc.currentIndex = index
                return vc
            }
        }
        // Default to Stage 1
        else {
            if let wordCat = selectedWordCategory {
                let vc = storyboard.instantiateViewController(withIdentifier: "OneWordTraceVC") as! OneWordTraceViewController
                vc.currentWordIndex = index
                vc.selectedCategory = wordCat
                return vc
            } else {
                let vc = storyboard.instantiateViewController(withIdentifier: "OneLetterTraceVC") as! OneLetterTraceViewController
                vc.contentType = contentType ?? .letters
                vc.currentIndex = index
                return vc
            }
        }
    }

    // MARK: - Analytics & Progress Business Logic
    func finalizeSession(index: Int, category: String, mistakes: Int, contentType: WritingContentType?) {
        // Calculate performance (Business Logic belongs in the Model/Manager)
        let penalty = mistakes * 10
        let score = max(0, 100 - penalty)
        
        // Save to Analytics Store
        let session = WritingSessionData(
            id: UUID(),
            date: Date(),
            childId: "default_child",
            lettersAccuracy: contentType == .letters ? score : 0,
            wordsAccuracy: contentType == nil ? score : 0, // Words have nil contentType here
            numbersAccuracy: contentType == .numbers ? score : 0
        )
        AnalyticsStore.shared.appendWritingSession(session)
        
        // Reset mistakes for this item
        saveMistakeCount(0, index: index, category: category)
    }
}
