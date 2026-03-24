import Foundation
import CoreData
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AksharApp", category: "AnalyticsStore")

final class AnalyticsStore {

    private let coreData: CoreDataStack
    private let childManager: ChildManager

    init(coreDataStack: CoreDataStack, childManager: ChildManager) {
        self.coreData     = coreDataStack
        self.childManager = childManager
    }

    // MARK: - Migration
    func migrateJSONToCoreData() {
        let legacyURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("analytics.json")
        guard FileManager.default.fileExists(atPath: legacyURL.path),
              let data   = try? Data(contentsOf: legacyURL),
              let legacy = try? JSONDecoder().decode(AnalyticsData.self, from: data)
        else { return }

        legacy.writingSessions.forEach        { appendWritingSession($0) }
        legacy.phonicsSessions.forEach        { appendPhonicsSession($0) }
        legacy.readingSessions.forEach        { appendReadingSession($0) }
        legacy.readingCheckpointResults.forEach { appendCheckpointResult($0) }

        try? FileManager.default.removeItem(at: legacyURL)
        logger.info("AnalyticsStore: legacy JSON migration complete.")
    }

    // MARK: - Writing Sessions
    func appendWritingSession(_ session: WritingSessionData) {
        let entity = WritingSessionEntity(context: coreData.context)
        entity.id               = session.id
        entity.date             = session.date
        entity.lettersAccuracy  = Int64(session.lettersAccuracy)
        entity.wordsAccuracy    = Int64(session.wordsAccuracy)
        entity.numbersAccuracy  = Int64(session.numbersAccuracy)
        entity.child            = childManager.currentChild
        coreData.deferredSave()
    }

    func fetchWritingSessions() -> [WritingSessionData] {
        let request: NSFetchRequest<WritingSessionEntity> = WritingSessionEntity.fetchRequest()
        request.predicate       = childPredicate()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchBatchSize  = 20
        do {
            return try coreData.context.fetch(request).map(mapWritingToStruct)
        } catch {
            logger.error("AnalyticsStore: fetchWritingSessions failed – \(error)")
            return []
        }
    }

    func fetchWritingSessions(from date: Date) -> [WritingSessionData] {
        let request: NSFetchRequest<WritingSessionEntity> = WritingSessionEntity.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            childPredicate(),
            NSPredicate(format: "date >= %@", date as NSDate)
        ])
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchBatchSize  = 20
        do {
            return try coreData.context.fetch(request).map(mapWritingToStruct)
        } catch {
            logger.error("AnalyticsStore: fetchWritingSessions(from:) failed – \(error)")
            return []
        }
    }

    // MARK: - Phonics Sessions
    func appendPhonicsSession(_ session: PhonicsSessionData) {
        let entity = PhonicsSessionEntity(context: coreData.context)
        entity.id            = session.id
        entity.date          = session.date
        entity.exerciseType  = session.exerciseType
        entity.correctCount  = Int64(session.correctCount)
        entity.totalAttempts = Int64(session.totalAttempts)
        entity.startTime     = session.startTime
        entity.endTime       = session.endTime
        entity.child         = childManager.currentChild
        coreData.deferredSave()
    }

    func fetchPhonicsSessions() -> [PhonicsSessionData] {
        let request: NSFetchRequest<PhonicsSessionEntity> = PhonicsSessionEntity.fetchRequest()
        request.predicate       = childPredicate()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchBatchSize  = 20
        do {
            return try coreData.context.fetch(request).map(mapPhonicsToStruct)
        } catch {
            logger.error("AnalyticsStore: fetchPhonicsSessions failed – \(error)")
            return []
        }
    }

    func fetchPhonicsSessions(from date: Date) -> [PhonicsSessionData] {
        let request: NSFetchRequest<PhonicsSessionEntity> = PhonicsSessionEntity.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            childPredicate(),
            NSPredicate(format: "date >= %@", date as NSDate)
        ])
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchBatchSize  = 20
        do {
            return try coreData.context.fetch(request).map(mapPhonicsToStruct)
        } catch {
            logger.error("AnalyticsStore: fetchPhonicsSessions(from:) failed – \(error)")
            return []
        }
    }

    // MARK: - Reading Sessions
    func appendReadingSession(_ session: ReadingSessionData) {
        let context = coreData.context

        let entity = ReadingSessionEntity(context: context)
        entity.id            = session.id
        entity.startTime     = session.startTime
        entity.endTime       = session.endTime
        entity.levelUnlocked = Int64(session.levelUnlocked)
        entity.totalDuration = session.totalDuration
        entity.child         = childManager.currentChild

        let storyReq: NSFetchRequest<StoryEntity> = StoryEntity.fetchRequest()
        storyReq.predicate  = NSPredicate(format: "storyId == %@", session.storyId)
        storyReq.fetchLimit = 1
        if let story = try? context.fetch(storyReq).first {
            entity.story = story
        }

        coreData.deferredSave()
    }

    func fetchReadingSessions() -> [ReadingSessionData] {
        let request: NSFetchRequest<ReadingSessionEntity> = ReadingSessionEntity.fetchRequest()
        request.predicate       = childPredicate()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        request.fetchBatchSize  = 20
        do {
            return try coreData.context.fetch(request).map(mapReadingToStruct)
        } catch {
            logger.error("AnalyticsStore: fetchReadingSessions failed – \(error)")
            return []
        }
    }

    func fetchReadingSessions(from date: Date) -> [ReadingSessionData] {
        let request: NSFetchRequest<ReadingSessionEntity> = ReadingSessionEntity.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            childPredicate(),
            NSPredicate(format: "startTime >= %@", date as NSDate)
        ])
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        request.fetchBatchSize  = 20
        do {
            return try coreData.context.fetch(request).map(mapReadingToStruct)
        } catch {
            logger.error("AnalyticsStore: fetchReadingSessions(from:) failed – \(error)")
            return []
        }
    }

    func updateReadingSessionEnd(sessionId: UUID, endTime: Date, additionalTime: TimeInterval = 0) {
        let request: NSFetchRequest<ReadingSessionEntity> = ReadingSessionEntity.fetchRequest()
        request.predicate  = NSPredicate(format: "id == %@", sessionId as CVarArg)
        request.fetchLimit = 1
        do {
            if let entity = try coreData.context.fetch(request).first {
                entity.endTime       = endTime
                entity.totalDuration += additionalTime
                coreData.saveContext()
            }
        } catch {
            logger.error("AnalyticsStore: updateReadingSessionEnd failed – \(error)")
        }
    }

    // MARK: - Checkpoint Results
    func appendCheckpointResult(_ result: ReadingCheckpointResultData) {
        let entity = CheckpointResultEntity(context: coreData.context)
        entity.id             = result.id
        entity.date           = result.date
        entity.storyId        = result.storyId
        entity.accuracy       = result.accuracy
        entity.checkpointText = result.checkpointText
        entity.child          = childManager.currentChild
        coreData.deferredSave()
    }

    func fetchCheckpointResults() -> [ReadingCheckpointResultData] {
        let request: NSFetchRequest<CheckpointResultEntity> = CheckpointResultEntity.fetchRequest()
        request.predicate       = childPredicate()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchBatchSize  = 20
        do {
            return try coreData.context.fetch(request).map(mapCheckpointResultToStruct)
        } catch {
            logger.error("AnalyticsStore: fetchCheckpointResults failed – \(error)")
            return []
        }
    }

    // MARK: - Private Helpers
    private func childPredicate() -> NSPredicate {
        NSPredicate(format: "child == %@", childManager.currentChild)
    }
}
