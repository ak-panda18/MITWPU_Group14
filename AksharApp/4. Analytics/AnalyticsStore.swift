import Foundation
import CoreData

final class AnalyticsStore {

    static let shared = AnalyticsStore()
    private let coreData = CoreDataStack.shared
    
    private init() {}

    // MARK: - WRITING SESSIONS
    
    func appendWritingSession(_ session: WritingSessionData) {
        let context = coreData.context
        let entity = WritingSessionEntity(context: context)
        entity.id = session.id
        entity.childId = session.childId
        entity.date = session.date
        entity.lettersAccuracy = Int64(session.lettersAccuracy)
        entity.wordsAccuracy = Int64(session.wordsAccuracy)
        entity.numbersAccuracy = Int64(session.numbersAccuracy)
        coreData.saveContext()
    }
    
    func saveOrUpdateWritingSession(_ session: WritingSessionData) {
        let context = coreData.context
        let request: NSFetchRequest<WritingSessionEntity> = WritingSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            let entity = results.first ?? WritingSessionEntity(context: context)
            entity.id = session.id
            entity.childId = session.childId
            entity.date = session.date
            entity.lettersAccuracy = Int64(session.lettersAccuracy)
            entity.wordsAccuracy = Int64(session.wordsAccuracy)
            entity.numbersAccuracy = Int64(session.numbersAccuracy)
            coreData.saveContext()
        } catch { print("Core Data Error: \(error)") }
    }
    
    // OPTIMIZED: Added 'from date' parameter
    func fetchWritingSessions(from date: Date? = nil) -> [WritingSessionData] {
        let request: NSFetchRequest<WritingSessionEntity> = WritingSessionEntity.fetchRequest()
        if let startDate = date {
            request.predicate = NSPredicate(format: "date >= %@", startDate as NSDate)
        }
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            let entities = try coreData.context.fetch(request)
            return entities.map { mapWritingToStruct($0) }
        } catch { return [] }
    }

    // MARK: - PHONICS SESSIONS
    
    func appendPhonicsSession(_ session: PhonicsSessionData) {
        let context = coreData.context
        let entity = PhonicsSessionEntity(context: context)
        entity.id = session.id
        entity.childId = session.childId
        entity.date = session.date
        entity.exerciseType = session.exerciseType
        entity.correctCount = Int64(session.correctCount)
        entity.totalAttempts = Int64(session.totalAttempts)
        entity.startTime = session.startTime
        entity.endTime = session.endTime
        coreData.saveContext()
    }
    
    // OPTIMIZED: Added 'from date' parameter
    func fetchPhonicsSessions(from date: Date? = nil) -> [PhonicsSessionData] {
        let request: NSFetchRequest<PhonicsSessionEntity> = PhonicsSessionEntity.fetchRequest()
        if let startDate = date {
            request.predicate = NSPredicate(format: "date >= %@", startDate as NSDate)
        }
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            let entities = try coreData.context.fetch(request)
            return entities.map { mapPhonicsToStruct($0) }
        } catch { return [] }
    }

    // MARK: - READING SESSIONS
    
    func appendReadingSession(_ session: ReadingSessionData) {
        let context = coreData.context
        let entity = ReadingSessionEntity(context: context)
        entity.id = session.id
        entity.childId = session.childId
        entity.storyId = session.storyId
        entity.startTime = session.startTime
        entity.endTime = session.endTime
        entity.levelUnlocked = Int64(session.levelUnlocked)
        coreData.saveContext()
    }
    
    func updateReadingSessionEnd(sessionId: UUID, endTime: Date) {
        let context = coreData.context
        let request: NSFetchRequest<ReadingSessionEntity> = ReadingSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
        if let entity = try? context.fetch(request).first {
            entity.endTime = endTime
            coreData.saveContext()
        }
    }
    
    // OPTIMIZED: Added 'from date' parameter
    func fetchReadingSessions(from date: Date? = nil) -> [ReadingSessionData] {
        let request: NSFetchRequest<ReadingSessionEntity> = ReadingSessionEntity.fetchRequest()
        if let startDate = date {
            request.predicate = NSPredicate(format: "startTime >= %@", startDate as NSDate)
        }
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
        
        do {
            let entities = try coreData.context.fetch(request)
            return entities.map { mapReadingToStruct($0) }
        } catch { return [] }
    }

    // MARK: - CHECKPOINT RESULTS
    
    func appendCheckpointResult(_ result: ReadingCheckpointResultData) {
        let context = coreData.context
        let entity = CheckpointResultEntity(context: context)
        entity.id = result.id
        entity.date = result.date
        entity.childId = result.childId
        entity.storyId = result.storyId
        entity.accuracy = result.accuracy
        entity.checkpointText = result.checkpointText
        coreData.saveContext()
    }
    
    func fetchCheckpointResults() -> [ReadingCheckpointResultData] {
        let request: NSFetchRequest<CheckpointResultEntity> = CheckpointResultEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        do {
            let entities = try coreData.context.fetch(request)
            return entities.map { mapCheckpointResultToStruct($0) }
        } catch { return [] }
    }
    // MARK: - Migration Helper
        func migrateJSONToCoreData() {
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("analytics.json")
            
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            
            print("Analytics: Migrating legacy JSON to Core Data...")
            
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let legacyData = try decoder.decode(AnalyticsData.self, from: data)
                
                // 1. Migrate Writing
                for session in legacyData.writingSessions {
                    // Check if exists before adding to avoid duplicates
                    let req: NSFetchRequest<WritingSessionEntity> = WritingSessionEntity.fetchRequest()
                    req.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
                    if (try? coreData.context.count(for: req)) == 0 {
                        appendWritingSession(session)
                    }
                }
                
                // 2. Migrate Reading
                for session in legacyData.readingSessions {
                    let req: NSFetchRequest<ReadingSessionEntity> = ReadingSessionEntity.fetchRequest()
                    req.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
                    if (try? coreData.context.count(for: req)) == 0 {
                        appendReadingSession(session)
                    }
                }
                
                // 3. Migrate Phonics
                for session in legacyData.phonicsSessions {
                    let req: NSFetchRequest<PhonicsSessionEntity> = PhonicsSessionEntity.fetchRequest()
                    req.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
                    if (try? coreData.context.count(for: req)) == 0 {
                        appendPhonicsSession(session)
                    }
                }
                
                // 4. Delete old file so we don't migrate again
                try FileManager.default.removeItem(at: fileURL)
                print("Analytics: Migration complete & legacy file deleted.")
                
            } catch {
                print("Analytics Migration Failed: \(error)")
            }
        }
}
