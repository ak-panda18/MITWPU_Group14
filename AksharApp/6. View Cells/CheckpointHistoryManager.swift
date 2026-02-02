import Foundation
import CoreData

class CheckpointHistoryManager {
    
    static let shared = CheckpointHistoryManager()
    // CHANGE: Use your existing CoreDataStack
    private let coreData = CoreDataStack.shared
    private init() {}
    
    // MARK: - Fetching History
    func getAllAttempts() -> [CheckpointAttempt] {
        let request: NSFetchRequest<CheckpointAttemptEntity> = CheckpointAttemptEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            let entities = try coreData.context.fetch(request)
            return entities.map { entity in
                let spokenString = entity.spokenWords ?? ""
                let spokenArray = spokenString.components(separatedBy: ",").filter { !$0.isEmpty }
                
                return CheckpointAttempt(
                    storyTitle: entity.storyTitle ?? "",
                    checkpointNumber: Int(entity.checkpointNumber),
                    accuracy: Int(entity.accuracy),
                    spokenWords: spokenArray,
                    timestamp: entity.timestamp ?? Date()
                )
            }
        } catch {
            print("Error loading history: \(error)")
            return []
        }
    }
    
    // MARK: - Filtered History
        func getAttempts(for storyTitle: String, checkpointNumber: Int) -> [CheckpointAttempt] {
            let request: NSFetchRequest<CheckpointAttemptEntity> = CheckpointAttemptEntity.fetchRequest()
            
            // Filter specifically for this story AND this checkpoint number
            request.predicate = NSPredicate(format: "storyTitle == %@ AND checkpointNumber == %d", storyTitle, Int64(checkpointNumber))
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            
            do {
                let entities = try coreData.context.fetch(request)
                return entities.map { entity in
                    let spokenString = entity.spokenWords ?? ""
                    let spokenArray = spokenString.components(separatedBy: ",").filter { !$0.isEmpty }
                    
                    return CheckpointAttempt(
                        storyTitle: entity.storyTitle ?? "",
                        checkpointNumber: Int(entity.checkpointNumber),
                        accuracy: Int(entity.accuracy),
                        spokenWords: spokenArray,
                        timestamp: entity.timestamp ?? Date()
                    )
                }
            } catch {
                print("Error fetching filtered history: \(error)")
                return []
            }
        }
    
    // MARK: - Saving History
    func save(attempt: CheckpointAttempt) {
        let context = coreData.context
        let entity = CheckpointAttemptEntity(context: context)
        
        entity.id = UUID()
        entity.storyTitle = attempt.storyTitle
        entity.checkpointNumber = Int64(attempt.checkpointNumber)
        entity.accuracy = Int64(attempt.accuracy)
        entity.timestamp = attempt.timestamp
        entity.spokenWords = attempt.spokenWords.joined(separator: ",")
        
        coreData.saveContext()
        print("CoreData: Saved Checkpoint Attempt")
    }
    
}
