import Foundation
import PencilKit
import UIKit

// MARK: - The State Model (Clean JSON)
struct WritingProgressState: Codable {
    var unlockedIndices: [String: Int] = [:]   
    var mistakeCounts: [String: Int] = [:]
    var lastActiveCategory: String = "3-letter"
}

class WritingGameplayManager {
    static let shared = WritingGameplayManager()
    
    private let progressFileName = "writing_progress.json"
    private var state: WritingProgressState = WritingProgressState()
    
    private(set) var sessionMistakes: Int = 0
    
    init() {
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
    func saveOneDrawing(_ drawing: PKDrawing, index: Int, category: String) {
        saveDrawing(drawing, index: index, category: category, stage: "one")
    }
    
    func loadOneDrawing(index: Int, category: String) -> PKDrawing? {
        return loadDrawing(index: index, category: category, stage: "one")
    }
    
    func deleteOneDrawing(index: Int, category: String) {
        deleteDrawing(index: index, category: category, stage: "one")
    }
    
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
    
    func saveSixDrawings(_ drawings: [PKDrawing], index: Int, category: String) {
        for (i, d) in drawings.enumerated() {
            saveDrawing(d, index: index, category: category, stage: "six", part: "\(i)")
        }
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

    // MARK: - Analytics & Progress Business Logic
    func trackMistake(index: Int, category: String) {
        sessionMistakes += 1
        print("Mistake added. Current sessionMistakes =", sessionMistakes)
    }
    func finalizeSession(
        index: Int,
        category: String,
        mistakes: Int,
        contentType: WritingContentType?,
        tracingCategory: TracingCategory? = nil
    ) {

        print("FINALIZING SESSION")
        print("Mistakes:", mistakes)

        let totalAttempts = mistakes + 1
        let sessionScore = Int((1.0 / Double(totalAttempts)) * 100.0)

        print("Session accuracy:", sessionScore)


        let allSessions = AnalyticsStore.shared.fetchWritingSessions()
        let relevantSessions: [WritingSessionData]

        if contentType == .letters {
            relevantSessions = allSessions.filter { $0.lettersAccuracy > 0 }
        }
        else if contentType == .numbers {
            relevantSessions = allSessions.filter { $0.numbersAccuracy > 0 }
        }
        else {
            relevantSessions = allSessions.filter { $0.wordsAccuracy > 0 }
        }


        let previousCount = relevantSessions.count

        var finalScore = sessionScore

        if previousCount > 0 {

            let previousTotal = relevantSessions.reduce(0) { partial, session in
                if contentType == .letters {
                    return partial + session.lettersAccuracy
                } else if contentType == .numbers {
                    return partial + session.numbersAccuracy
                } else {
                    return partial + session.wordsAccuracy
                }
            }

            let previousAverage = previousTotal / previousCount

            finalScore = Int(
                (Double(previousAverage * previousCount) + Double(sessionScore))
                /
                Double(previousCount + 1)
            )

            print("Previous average:", previousAverage)
            print("New combined average:", finalScore)
        }

        let session = WritingSessionData(
            id: UUID(),
            date: Date(),
            childId: "default_child",
            lettersAccuracy: contentType == .letters ? finalScore : 0,
            wordsAccuracy: tracingCategory != nil ? finalScore : 0,
            numbersAccuracy: contentType == .numbers ? finalScore : 0
        )

        AnalyticsStore.shared.appendWritingSession(session)

        sessionMistakes = 0
    }


    // MARK: - Session Management
    func startNewSession() {
        sessionMistakes = 0
    }
    
    func didEarnSticker() -> Bool {
        return sessionMistakes <= 2
    }

    // MARK: - Dashboard Helpers (MVC Logic)
    func getLastActiveItemDescription() -> String {
        let category = state.lastActiveCategory
        let index = getHighestUnlockedIndex(category: category)
        
        if category == "letters" {
            let baseIndex = index / 2
            let isLowercase = (index % 2 != 0)
            let asciiStart = isLowercase ? 97 : 65
            
            if baseIndex < 26 {
                let charString = String(UnicodeScalar(asciiStart + baseIndex)!)
                return "Letter: '\(charString)'"
            }
            return "Letter Tracing"
            
        } else if category == "numbers" {
            return "Number: '\(index)'"
        } else {
            let allWords = TracingWordLoader.loadWords()
            let categoryWords = allWords.words(for: category)
            if !categoryWords.isEmpty {
                let safeIndex = min(index, categoryWords.count - 1)
                let word = categoryWords[safeIndex].word
                return "Word: '\(word)'"
            }
            return "Word Tracing"
        }
    }
    // MARK: - Letter / Number Helpers
    func getCharacterString(for index: Int, contentType: WritingContentType) -> String {

        switch contentType {
        case .words:fatalError("Words not supported in OneLetterTraceViewController")
        case .letters:
            let baseIndex = index / 2
            let isLowercase = (index % 2 != 0)
            let asciiStart = isLowercase ? 97 : 65
            return String(UnicodeScalar(asciiStart + baseIndex)!)

        case .numbers:
            return "\(index)"
        }
    }
    
    func isIndexUnlocked(index: Int, category: String) -> Bool {
        let unlocked = getHighestUnlockedIndex(category: category)
        return index <= unlocked
    }
    
    // MARK: - Preview Display Helpers
    func currentLetterDisplay() -> String {
        let index = getHighestUnlockedIndex(category: "letters")
        return getCharacterString(for: index, contentType: .letters)
    }

    func currentNumberDisplay() -> String {
        let index = getHighestUnlockedIndex(category: "numbers")
        return getCharacterString(for: index, contentType: .numbers)
    }

    func currentWordDisplay() -> String {
        let category = lastActiveCategory
        let words = TracingWordLoader.loadWords().words(for: category)

        guard !words.isEmpty else { return "--" }

        let index = getHighestUnlockedIndex(category: category)
        let safeIndex = min(index, words.count - 1)
        return words[safeIndex].word
    }
    
    // MARK: - Progress Helpers
    func progress(for category: String, total: Int) -> Float {
        guard total > 0 else { return 0 }
        let completed = getHighestUnlockedIndex(category: category)
        return min(max(Float(completed) / Float(total), 0), 1)
    }

    func letterProgress() -> Float {
        return progress(for: "letters", total: 52)
    }

    func numberProgress() -> Float {
        return progress(for: "numbers", total: 10)
    }

    func wordProgress() -> Float {
        let words = TracingWordLoader.loadWords().words(for: lastActiveCategory)
        return progress(for: lastActiveCategory, total: words.count)
    }
}

