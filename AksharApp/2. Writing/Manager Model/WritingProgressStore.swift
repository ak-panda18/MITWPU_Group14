import Foundation
import CoreData
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AksharApp", category: "WritingProgressStore")

final class WritingProgressStore {

    private let coreData: CoreDataStack
    private let childManager: ChildManager

    // MARK: - Init
    init(coreDataStack: CoreDataStack, childManager: ChildManager) {
        self.coreData     = coreDataStack
        self.childManager = childManager
        migrateJSONIfNeeded()
    }

    // MARK: - Category
    var lastActiveCategory: String {
        get { entity().lastActiveCategory ?? "letters" }
        set { entity().lastActiveCategory = newValue; coreData.saveContext() }
    }

    // MARK: - Unlock
    func getHighestUnlockedIndex(category: String) -> Int {
        return unlockedIndices()[category] ?? 0
    }

    func unlockNextItem(category: String, currentIndex: Int) {
        var indices = unlockedIndices()
        let current = indices[category] ?? 0
        guard currentIndex >= current else { return }
        indices[category] = currentIndex + 1
        saveUnlockedIndices(indices)
    }

    func isIndexUnlocked(index: Int, category: String) -> Bool {
        return index <= getHighestUnlockedIndex(category: category)
    }

    // MARK: - Mistakes
    func getMistakeCount(index: Int, category: String) -> Int {
        return mistakeCounts()["\(category)_\(index)"] ?? 0
    }

    func saveMistakeCount(_ count: Int, index: Int, category: String) {
        var counts = mistakeCounts()
        counts["\(category)_\(index)"] = count
        saveMistakeCounts(counts)
    }

    // MARK: - Character Helpers
    func characterString(for index: Int, contentType: WritingContentType) -> String {
        switch contentType {
        case .words:
            preconditionFailure("WritingProgressStore: words handled by WordTraceContentProvider")
        case .letters:
            let base       = index / 2
            let isLower    = (index % 2 != 0)
            let asciiStart = isLower ? 97 : 65
            return String(UnicodeScalar(asciiStart + base)!)
        case .numbers:
            return "\(index)"
        }
    }

    // MARK: - Progress Fraction
    func progress(for category: String, total: Int) -> Float {
        guard total > 0 else { return 0 }
        return min(max(Float(getHighestUnlockedIndex(category: category)) / Float(total), 0), 1)
    }

    private func entity() -> WritingProgressEntity {
        let childId = childManager.currentChild.id?.uuidString ?? "default"
        return entityForChild(childId: childId)
    }

    private func entityForChild(childId: String) -> WritingProgressEntity {
        let request: NSFetchRequest<WritingProgressEntity> = WritingProgressEntity.fetchRequest()

        if hasChildIdAttribute() {
            request.predicate = NSPredicate(format: "childId == %@", childId)
        }
        request.fetchLimit = 1

        if let existing = try? coreData.context.fetch(request).first {
            return existing
        }

        let e = WritingProgressEntity(context: coreData.context)
        e.lastActiveCategory  = "letters"
        e.unlockedIndicesData = encode([String: Int]())
        e.mistakeCountsData   = encode([String: Int]())

        if hasChildIdAttribute() {
            e.setValue(childId, forKey: "childId")
        }

        coreData.saveContext()
        logger.info("WritingProgressStore: created new entity for child \(childId)")
        return e
    }

    private func hasChildIdAttribute() -> Bool {
        let model = coreData.persistentContainer.managedObjectModel
        let entity = model.entitiesByName["WritingProgressEntity"]
        return entity?.attributesByName["childId"] != nil
    }

    private func unlockedIndices() -> [String: Int] {
        decode(entity().unlockedIndicesData)
    }

    private func mistakeCounts() -> [String: Int] {
        decode(entity().mistakeCountsData)
    }

    private func saveUnlockedIndices(_ d: [String: Int]) {
        entity().unlockedIndicesData = encode(d)
        coreData.saveContext()
    }

    private func saveMistakeCounts(_ d: [String: Int]) {
        entity().mistakeCountsData = encode(d)
        coreData.saveContext()
    }

    private func encode(_ d: [String: Int]) -> String {
        guard let data = try? JSONEncoder().encode(d),
              let str = String(data: data, encoding: .utf8)
        else { return "{}" }
        return str
    }

    private func decode(_ string: String?) -> [String: Int] {
        guard let s = string,
              let data = s.data(using: .utf8),
              let result = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return result
    }

    // MARK: - One-time JSON Migration
    private func migrateJSONIfNeeded() {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("writing_progress.json")
        guard FileManager.default.fileExists(atPath: url.path),
              let data   = try? Data(contentsOf: url),
              let legacy = try? JSONDecoder().decode(LegacyWritingProgressState.self, from: data)
        else { return }

        let e = entity()
        e.lastActiveCategory  = legacy.lastActiveCategory
        e.unlockedIndicesData = encode(legacy.unlockedIndices)
        e.mistakeCountsData   = encode(legacy.mistakeCounts)
        coreData.saveContext()

        try? FileManager.default.removeItem(at: url)
        logger.info("WritingProgressStore: migrated legacy JSON to Core Data.")
    }
}

private struct LegacyWritingProgressState: Codable {
    var unlockedIndices:    [String: Int] = [:]
    var mistakeCounts:      [String: Int] = [:]
    var lastActiveCategory: String = "letters"
}
