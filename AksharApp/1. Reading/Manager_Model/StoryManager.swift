import Foundation
import CoreData

class StoryManager {
    // 1. Singleton: This lets you call StoryManager.shared from anywhere
    static let shared = StoryManager()
    
    // 2. Existing JSON logic (moved here from your VCs)
    private let storiesResponse = StoriesResponse()
    private let checkpointsResponse = CheckpointsResponse()

    // MARK: - Fetching Content (JSON)
    func getStories(for difficulty: String) -> [Story] {
        return storiesResponse.getStories(difficulty: difficulty)
    }
    
    func getCheckpointItem(storyId: String, pageNumber: Int) -> CheckpointItem? {
        return checkpointsResponse.item(for: storyId, pageNumber: pageNumber)
    }

    // MARK: - Core Data Logic (The New Part)
    
    /// Returns: (savedPageIndex, isStoryCompleted)
    func getProgress(for storyId: String) -> (Int, Bool) {
        let context = CoreDataStack.shared.context
        let request: NSFetchRequest<StoryEntity> = StoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "storyId == %@", storyId)
        
        do {
            if let result = try context.fetch(request).first {
                // Return the saved index and completion status
                return (Int(result.lastPageIndex), result.isCompleted)
            }
        } catch {
            print("Error fetching progress: \(error)")
        }
        return (0, false) // Default if never read before
    }

    func saveProgress(storyId: String, pageIndex: Int, didComplete: Bool? = nil) {
        let context = CoreDataStack.shared.context
        
        // 1. Try to find the existing record for this story
        let request: NSFetchRequest<StoryEntity> = StoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "storyId == %@", storyId)
        
        do {
            let entity: StoryEntity
            if let result = try context.fetch(request).first {
                entity = result // Found it, update it
            } else {
                entity = StoryEntity(context: context) // Didn't find it, create new
                entity.storyId = storyId
                entity.completedCheckpoints = ""
            }
            
            // 2. Update the values
            entity.lastPageIndex = Int16(pageIndex)
            entity.lastReadDate = Date()
            
            if let completed = didComplete {
                entity.isCompleted = completed
            }
            
            // 3. Save to database
            CoreDataStack.shared.saveContext()
        } catch {
            print("Error saving progress: \(error)")
        }
    }
    
    // MARK: - Checkpoint Logic
    
    func isCheckpointCompleted(storyId: String, checkpointText: String) -> Bool {
        // Create a unique ID for the checkpoint based on its text
        let cleanText = checkpointText.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        let checkId = String(cleanText.prefix(50))
        
        let context = CoreDataStack.shared.context
        let request: NSFetchRequest<StoryEntity> = StoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "storyId == %@", storyId)
        
        if let result = try? context.fetch(request).first,
           let saved = result.completedCheckpoints {
            return saved.contains(checkId)
        }
        return false
    }
    
    func markCheckpointCompleted(storyId: String, checkpointText: String) {
        let cleanText = checkpointText.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        let checkId = String(cleanText.prefix(50))
        
        let context = CoreDataStack.shared.context
        let request: NSFetchRequest<StoryEntity> = StoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "storyId == %@", storyId)
        
        do {
            if let entity = try context.fetch(request).first {
                var current = entity.completedCheckpoints ?? ""
                if !current.contains(checkId) {
                    // Append the new checkpoint ID
                    current += (current.isEmpty ? "" : ",") + checkId
                    entity.completedCheckpoints = current
                    CoreDataStack.shared.saveContext()
                }
            }
        } catch {
            print("Error saving checkpoint: \(error)")
        }
    }
}
