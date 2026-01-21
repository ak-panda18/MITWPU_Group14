//
//  TracingProgressManager.swift
//  AksharApp
//

import Foundation
import PencilKit
import UIKit

enum WordCategory: String {
    case three = "3-letter"
    case four  = "4-letter"
    case five  = "5-letter"
    case six   = "6-letter"
    case power = "power"
}

final class TracingProgressManager {
    static let shared = TracingProgressManager()
    private init() {}
    private(set) var currentActiveLetterIndex: Int = 0
    private(set) var currentActiveNumberIndex: Int = 0
    private let lastWordCategoryKey = "akshar_last_word_category"
    var activeWordIndexByCategory: [String: Int] = [:]
    var lastActiveWordCategory: WordCategory {
        get {
            let raw = UserDefaults.standard.string(forKey: lastWordCategoryKey)
            return WordCategory(rawValue: raw ?? "") ?? .three
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: lastWordCategoryKey)
        }
    }

    // MARK: - COMPATIBILITY LAYER 
    var oneLetterDrawing: [Int: PKDrawing] = [:]
    var oneNumberDrawing: [Int: PKDrawing] = [:]
    var twoLetterDrawing: [Int: (PKDrawing, PKDrawing)] = [:]
    var twoNumberDrawing: [Int: (PKDrawing, PKDrawing)] = [:]
    var sixLetterDrawings: [Int: [PKDrawing]] = [:]
    var sixNumberDrawings: [Int: [PKDrawing]] = [:]

    func advanceStage(for index: Int, contentType: WritingContentType) {
        switch contentType {
        case .letters: if index >= highestUnlockedLetter { highestUnlockedLetter = index + 1 }
        case .numbers: if index >= highestUnlockedNumber { highestUnlockedNumber = index + 1 }
        }
    }
    
    func isTwoLetterCompleted(index: Int, type: WritingContentType) -> Bool {
        if type == .letters { if twoLetterDrawing[index] != nil { return true } }
        else { if twoNumberDrawing[index] != nil { return true } }
        return loadTwoLetterDrawings(index: index, type: type) != nil
    }

    // MARK: - Persistent Unlock State
    func syncCurrentActiveLetterWithUnlockedProgress() {
        currentActiveLetterIndex = highestUnlockedLetter
    }

    func setCurrentActiveLetterIndex(_ index: Int) {
        let maxUnlocked = highestUnlockedLetter
        currentActiveLetterIndex = min(index, maxUnlocked)
    }
    
    func syncCurrentActiveNumberWithUnlockedProgress() {
        currentActiveNumberIndex = highestUnlockedNumber
    }
    
    func setCurrentActiveNumberIndex(_ index: Int) {
        let maxUnlocked = highestUnlockedNumber
        currentActiveNumberIndex = min(index, maxUnlocked)
    }
    func setActiveWord(index: Int, category: String) {
        activeWordIndexByCategory[category] = index
    }

    func getActiveWordIndex(category: String) -> Int {
        return activeWordIndexByCategory[category] ?? 0
    }
    
    var highestUnlockedLetter: Int {
        get { UserDefaults.standard.integer(forKey: "akshar_unlocked_letter_idx") }
        set { UserDefaults.standard.set(newValue, forKey: "akshar_unlocked_letter_idx") }
    }

    var highestUnlockedNumber: Int {
        get { UserDefaults.standard.integer(forKey: "akshar_unlocked_number_idx") }
        set { UserDefaults.standard.set(newValue, forKey: "akshar_unlocked_number_idx") }
    }
    
    func highestUnlockedWordIndex(for category: String) -> Int {
        return UserDefaults.standard.integer(forKey: "akshar_unlocked_word_\(category)")
    }

    func advanceWordStage(for category: String, currentIndex: Int) {
        let currentMax = highestUnlockedWordIndex(for: category)
        if currentIndex >= currentMax {
            UserDefaults.standard.set(currentIndex + 1, forKey: "akshar_unlocked_word_\(category)")
        }
    }

    func highestUnlockedIndex(for contentType: WritingContentType) -> Int {
        switch contentType {
        case .letters: return highestUnlockedLetter
        case .numbers: return highestUnlockedNumber
        }
    }
    
    // MARK: - STAGE COMPLETION FLAGS
    func setWordStageCompleted(index: Int, category: String, stage: String) {
        UserDefaults.standard.set(true, forKey: "akshar_word_completed_\(category)_\(index)_\(stage)")
    }
    
    func isWordStageCompleted(index: Int, category: String, stage: String) -> Bool {
        return UserDefaults.standard.bool(forKey: "akshar_word_completed_\(category)_\(index)_\(stage)")
    }

    // MARK: - WORD STORAGE
    func saveOneWordDrawing(_ drawing: PKDrawing, index: Int, category: String) {
        let url = getWordFileURL(category: category, index: index, stage: "one")
        writeData(drawing.dataRepresentation(), to: url)
        setWordStageCompleted(index: index, category: category, stage: "one")
    }

    func loadOneWordDrawing(index: Int, category: String) -> PKDrawing? {
        let url = getWordFileURL(category: category, index: index, stage: "one")
        if let data = readData(from: url), let drawing = try? PKDrawing(data: data) {
            return drawing
        }
        if isWordStageCompleted(index: index, category: category, stage: "one") {
            return PKDrawing()
        }
        return nil
    }
    
    func deleteOneWordDrawing(index: Int, category: String) {
        removeFile(at: getWordFileURL(category: category, index: index, stage: "one"))
    }
    
    func saveTwoWordDrawings(top: PKDrawing, bottom: PKDrawing, index: Int, category: String) {
        let topUrl = getWordFileURL(category: category, index: index, stage: "two", part: "top")
        let bottomUrl = getWordFileURL(category: category, index: index, stage: "two", part: "bottom")
        writeData(top.dataRepresentation(), to: topUrl)
        writeData(bottom.dataRepresentation(), to: bottomUrl)
        setWordStageCompleted(index: index, category: category, stage: "two")
    }

    func loadTwoWordDrawings(index: Int, category: String) -> (PKDrawing, PKDrawing)? {
        let topUrl = getWordFileURL(category: category, index: index, stage: "two", part: "top")
        let bottomUrl = getWordFileURL(category: category, index: index, stage: "two", part: "bottom")
        if let tD = readData(from: topUrl), let bD = readData(from: bottomUrl),
           let t = try? PKDrawing(data: tD), let b = try? PKDrawing(data: bD) {
            return (t, b)
        }
        if isWordStageCompleted(index: index, category: category, stage: "two") {
            return (PKDrawing(), PKDrawing())
        }
        return nil
    }
    
    func deleteTwoWordDrawings(index: Int, category: String) {
        removeFile(at: getWordFileURL(category: category, index: index, stage: "two", part: "top"))
        removeFile(at: getWordFileURL(category: category, index: index, stage: "two", part: "bottom"))
    }
    
    func saveSixWordDrawings(_ drawings: [PKDrawing], index: Int, category: String) {
        for (i, d) in drawings.enumerated() {
            let url = getWordFileURL(category: category, index: index, stage: "six", part: "\(i)")
            writeData(d.dataRepresentation(), to: url)
        }
        setWordStageCompleted(index: index, category: category, stage: "six")
    }

    func loadSixWordDrawings(index: Int, category: String) -> [PKDrawing]? {
        var res: [PKDrawing] = []
        var allFound = true
        for i in 0..<6 {
            let url = getWordFileURL(category: category, index: index, stage: "six", part: "\(i)")
            if let d = readData(from: url), let dr = try? PKDrawing(data: d) {
                res.append(dr)
            } else {
                allFound = false
            }
        }
        if allFound && res.count == 6 { return res }
        
        if isWordStageCompleted(index: index, category: category, stage: "six") {
            return Array(repeating: PKDrawing(), count: 6)
        }
        return nil
    }
    
    func deleteSixWordDrawings(index: Int, category: String) {
        for i in 0..<6 {
            removeFile(at: getWordFileURL(category: category, index: index, stage: "six", part: "\(i)"))
        }
    }

    // MARK: - Legacy Storage Helpers
    func saveOneLetterDrawing(_ drawing: PKDrawing, index: Int, type: WritingContentType) {
        let url = getFileURL(type: type, index: index, stage: "one")
        writeData(drawing.dataRepresentation(), to: url)
        if type == .letters { oneLetterDrawing[index] = drawing }
        else { oneNumberDrawing[index] = drawing }
    }

    func loadOneLetterDrawing(index: Int, type: WritingContentType) -> PKDrawing? {
        if type == .letters, let d = oneLetterDrawing[index] { return d }
        if type == .numbers, let d = oneNumberDrawing[index] { return d }
        let url = getFileURL(type: type, index: index, stage: "one")
        guard let data = readData(from: url) else { return nil }
        return try? PKDrawing(data: data)
    }
    
    func deleteOneLetterDrawing(index: Int, type: WritingContentType) {
        removeFile(at: getFileURL(type: type, index: index, stage: "one"))
        if type == .letters { oneLetterDrawing.removeValue(forKey: index) }
        else { oneNumberDrawing.removeValue(forKey: index) }
    }
    
    func saveTwoLetterDrawings(top: PKDrawing, bottom: PKDrawing, index: Int, type: WritingContentType) {
        let topUrl = getFileURL(type: type, index: index, stage: "two", part: "top")
        let bottomUrl = getFileURL(type: type, index: index, stage: "two", part: "bottom")
        writeData(top.dataRepresentation(), to: topUrl)
        writeData(bottom.dataRepresentation(), to: bottomUrl)
        if type == .letters { twoLetterDrawing[index] = (top, bottom) }
        else { twoNumberDrawing[index] = (top, bottom) }
    }

    func loadTwoLetterDrawings(index: Int, type: WritingContentType) -> (PKDrawing, PKDrawing)? {
        if type == .letters, let d = twoLetterDrawing[index] { return d }
        if type == .numbers, let d = twoNumberDrawing[index] { return d }
        let topUrl = getFileURL(type: type, index: index, stage: "two", part: "top")
        let bottomUrl = getFileURL(type: type, index: index, stage: "two", part: "bottom")
        guard let tD = readData(from: topUrl), let bD = readData(from: bottomUrl),
              let t = try? PKDrawing(data: tD), let b = try? PKDrawing(data: bD) else { return nil }
        return (t, b)
    }
    
    func deleteTwoLetterDrawings(index: Int, type: WritingContentType) {
        removeFile(at: getFileURL(type: type, index: index, stage: "two", part: "top"))
        removeFile(at: getFileURL(type: type, index: index, stage: "two", part: "bottom"))
        if type == .letters { twoLetterDrawing.removeValue(forKey: index) }
        else { twoNumberDrawing.removeValue(forKey: index) }
    }
    
    func saveSixLetterDrawings(_ drawings: [PKDrawing], index: Int, type: WritingContentType) {
        for (i, d) in drawings.enumerated() {
            let url = getFileURL(type: type, index: index, stage: "six", part: "\(i)")
            writeData(d.dataRepresentation(), to: url)
        }
        if type == .letters { sixLetterDrawings[index] = drawings }
        else { sixNumberDrawings[index] = drawings }
    }
    
    func loadSixLetterDrawings(index: Int, type: WritingContentType) -> [PKDrawing]? {
        if type == .letters, let d = sixLetterDrawings[index] { return d }
        if type == .numbers, let d = sixNumberDrawings[index] { return d }
        var res: [PKDrawing] = []
        for i in 0..<6 {
            let url = getFileURL(type: type, index: index, stage: "six", part: "\(i)")
            guard let d = readData(from: url), let dr = try? PKDrawing(data: d) else { return nil }
            res.append(dr)
        }
        return res
    }
    
    func deleteSixLetterDrawings(index: Int, type: WritingContentType) {
        for i in 0..<6 { removeFile(at: getFileURL(type: type, index: index, stage: "six", part: "\(i)")) }
        if type == .letters { sixLetterDrawings.removeValue(forKey: index) }
        else { sixNumberDrawings.removeValue(forKey: index) }
    }

    // MARK: - File Helpers
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private func getFileURL(type: WritingContentType, index: Int, stage: String, part: String = "") -> URL {
        let typeStr = (type == .letters) ? "letters" : "numbers"
        let fileName = "trace_\(typeStr)_\(index)_\(stage)_\(part).data"
        return getDocumentsDirectory().appendingPathComponent(fileName)
    }
    private func getWordFileURL(category: String, index: Int, stage: String, part: String = "") -> URL {
        let catSanitized = category.replacingOccurrences(of: " ", with: "_")
        let fileName = "trace_word_\(catSanitized)_\(index)_\(stage)_\(part).data"
        return getDocumentsDirectory().appendingPathComponent(fileName)
    }
    private func writeData(_ data: Data, to url: URL) { try? data.write(to: url) }
    private func readData(from url: URL) -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }
    private func removeFile(at url: URL) { try? FileManager.default.removeItem(at: url) }
    
    func getMistakeCount(index: Int, category: String) -> Int {
            return UserDefaults.standard.integer(forKey: "mistake_\(category)_\(index)")
        }
        func saveMistakeCount(_ count: Int, index: Int, category: String) {
            UserDefaults.standard.set(count, forKey: "mistake_\(category)_\(index)")
        }
    // MARK: - Session Persistence
        
        func getSessionID(index: Int, category: String) -> UUID? {
            if let uuidString = UserDefaults.standard.string(forKey: "session_\(category)_\(index)") {
                return UUID(uuidString: uuidString)
            }
            return nil
        }
        
        func saveSessionID(_ id: UUID, index: Int, category: String) {
            UserDefaults.standard.set(id.uuidString, forKey: "session_\(category)_\(index)")
        }
        
        func deleteSessionID(index: Int, category: String) {
            UserDefaults.standard.removeObject(forKey: "session_\(category)_\(index)")
        }
}
