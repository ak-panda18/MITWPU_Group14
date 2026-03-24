import Foundation
import PencilKit
import UIKit

class WritingGameplayManager {

    // MARK: - Sub-stores
    let progressStore:  WritingProgressStore
    let drawingStore:   WritingDrawingStore
    let sessionManager: WritingSessionManager

    private let allTracingWords: [TracingWord]

    // MARK: - Init
    init(progressStore:  WritingProgressStore,
         drawingStore:   WritingDrawingStore,
         sessionManager: WritingSessionManager) {
        self.progressStore  = progressStore
        self.drawingStore   = drawingStore
        self.sessionManager = sessionManager
        self.allTracingWords = TracingWordLoader.loadWords()
    }

    // MARK: - Progress & Unlocking
    var lastActiveCategory: String {
        get { progressStore.lastActiveCategory }
        set { progressStore.lastActiveCategory = newValue }
    }

    func getHighestUnlockedIndex(category: String) -> Int  { progressStore.getHighestUnlockedIndex(category: category) }
    func unlockNextItem(category: String, currentIndex: Int) { progressStore.unlockNextItem(category: category, currentIndex: currentIndex) }
    func isIndexUnlocked(index: Int, category: String) -> Bool { progressStore.isIndexUnlocked(index: index, category: category) }
    func getMistakeCount(index: Int, category: String) -> Int { progressStore.getMistakeCount(index: index, category: category) }
    func saveMistakeCount(_ count: Int, index: Int, category: String) { progressStore.saveMistakeCount(count, index: index, category: category) }
    func getCharacterString(for index: Int, contentType: WritingContentType) -> String { progressStore.characterString(for: index, contentType: contentType) }

    // MARK: - Drawing
    func saveDrawing(_ d: PKDrawing, index: Int, category: String, stage: String, part: String = "main") { drawingStore.saveDrawing(d, index: index, category: category, stage: stage, part: part) }
    func loadDrawing(index: Int, category: String, stage: String, part: String = "main") -> PKDrawing? { drawingStore.loadDrawing(index: index, category: category, stage: stage, part: part) }
    func deleteDrawing(index: Int, category: String, stage: String, part: String = "main") { drawingStore.deleteDrawing(index: index, category: category, stage: stage, part: part) }

    func saveOneDrawing(_ d: PKDrawing, index: Int, category: String)   { drawingStore.saveOneDrawing(d, index: index, category: category) }
    func loadOneDrawing(index: Int, category: String) -> PKDrawing?     { drawingStore.loadOneDrawing(index: index, category: category) }
    func deleteOneDrawing(index: Int, category: String)                 { drawingStore.deleteOneDrawing(index: index, category: category) }

    func saveTwoDrawings(top: PKDrawing, bottom: PKDrawing, index: Int, category: String) { drawingStore.saveTwoDrawings(top: top, bottom: bottom, index: index, category: category) }
    func loadTwoDrawings(index: Int, category: String) -> (PKDrawing, PKDrawing)? { drawingStore.loadTwoDrawings(index: index, category: category) }
    func deleteTwoDrawings(index: Int, category: String) { drawingStore.deleteTwoDrawings(index: index, category: category) }

    func saveSixDrawings(_ drawings: [PKDrawing], index: Int, category: String) {
        drawingStore.saveSixDrawings(drawings, index: index, category: category)
        progressStore.unlockNextItem(category: category, currentIndex: index)
    }
    func loadSixDrawings(index: Int, category: String) -> [PKDrawing]? { drawingStore.loadSixDrawings(index: index, category: category) }
    func deleteSixDrawings(index: Int, category: String)               { drawingStore.deleteSixDrawings(index: index, category: category) }

    // MARK: - Session
    var sessionMistakes: Int { sessionManager.sessionMistakes }

    func startNewSession()                          { sessionManager.startNewSession() }
    func trackMistake(index: Int, category: String) { sessionManager.trackMistake(index: index, category: category) }
    func didEarnSticker() -> Bool                   { sessionManager.didEarnSticker() }
    func finalizeSession(index: Int, category: String, mistakes: Int,
                         contentType: WritingContentType?,
                         tracingCategory: TracingCategory? = nil) {
        sessionManager.finalizeSession(index: index, category: category,
                                       mistakes: mistakes, contentType: contentType,
                                       tracingCategory: tracingCategory)
    }

    // MARK: - Dashboard & Preview Helpers
    func getLastActiveItemDescription() -> String {
        let category = progressStore.lastActiveCategory
        let index    = progressStore.getHighestUnlockedIndex(category: category)

        switch category {
        case "letters":
            let char = progressStore.characterString(for: index, contentType: .letters)
            return "Letter: '\(char)'"
        case "numbers":
            return "Number: '\(index)'"
        default:
            let words = allTracingWords.words(for: category)
            guard !words.isEmpty else { return "Word Tracing" }
            return "Word: '\(words[min(index, words.count - 1)].word)'"
        }
    }

    func currentLetterDisplay() -> String {
        progressStore.characterString(
            for: progressStore.getHighestUnlockedIndex(category: "letters"),
            contentType: .letters
        )
    }

    func currentNumberDisplay() -> String {
        progressStore.characterString(
            for: progressStore.getHighestUnlockedIndex(category: "numbers"),
            contentType: .numbers
        )
    }

    func currentWordDisplay() -> String {
        let category = progressStore.lastActiveCategory
        let words    = allTracingWords.words(for: category)
        guard !words.isEmpty else { return "--" }
        let index = progressStore.getHighestUnlockedIndex(category: category)
        return words[min(index, words.count - 1)].word
    }

    func letterProgress() -> Float { progressStore.progress(for: "letters", total: 52) }
    func numberProgress() -> Float { progressStore.progress(for: "numbers", total: 10) }
    func wordProgress()   -> Float {
        let words = allTracingWords.words(for: progressStore.lastActiveCategory)
        return progressStore.progress(for: progressStore.lastActiveCategory, total: words.count)
    }
}
