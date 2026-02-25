import Foundation
import CoreData

class StoryManager {
    static let shared = StoryManager()

    private var stories: [Story] = []
    private(set) var checkpoints: [CheckpointSet] = []
        
    init() {
        let storiesData = BundleDataLoader.shared.load("stories", as: StoriesResponse.self)
        self.stories = storiesData.stories
        
        let checkpointsData = BundleDataLoader.shared.load("checkpoints", as: CheckpointsResponse.self)
        self.checkpoints = checkpointsData.checkpoints
    }

    // MARK: - Story Retrieval Logic
    func getStories(for difficulty: String) -> [Story] {
        return stories.filter { $0.difficulty == difficulty }
    }
        
    func getStory(by id: String) -> Story? {
        return stories.first { $0.id == id }
    }
        
    func getRandomStory() -> Story? {
        return stories.randomElement()
    }
        
    // MARK: - Navigation Helpers
    func findNextStory(after storyId: String) -> Story? {
        guard let index = stories.firstIndex(where: { $0.id == storyId }),
              index < stories.count - 1 else { return nil }
        return stories[index + 1]
    }
    
    func getCheckpointItem(storyId: String, pageNumber: Int) -> CheckpointItem? {
        guard let set = checkpoints.first(where: { $0.id == storyId }) else { return nil }
        return set.content.first(where: { $0.pageNumber == pageNumber })
    }
    

    // MARK: - Core Data Logic
    func getProgress(for storyId: String) -> (Int, Bool) {
        let context = CoreDataStack.shared.context
        let request: NSFetchRequest<StoryEntity> = StoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "storyId == %@", storyId)
        
        do {
            if let result = try context.fetch(request).first {
                return (Int(result.lastPageIndex), result.isCompleted)
            }
        } catch {
            print("Error fetching progress: \(error)")
        }
        return (0, false)
    }
    
    func indexToHighlight(for difficulty: String) -> Int? {

        let stories = getStories(for: difficulty)

        for (index, story) in stories.enumerated() {

            let (savedIndex, isCompleted) = getProgress(for: story.id)

            if !isCompleted && savedIndex > 0 {
                return index
            }
        }

        for (index, story) in stories.enumerated() {

            let (_, isCompleted) = getProgress(for: story.id)

            if !isCompleted {
                return index
            }
        }

        return nil
    }


    func saveProgress(storyId: String, pageIndex: Int, didComplete: Bool? = nil) {
        let context = CoreDataStack.shared.context
        let request: NSFetchRequest<StoryEntity> = StoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "storyId == %@", storyId)
        
        do {
            let entity: StoryEntity
            if let result = try context.fetch(request).first {
                entity = result
            } else {
                entity = StoryEntity(context: context)
                entity.storyId = storyId
                entity.completedCheckpoints = ""
            }
            
            entity.lastPageIndex = Int16(pageIndex)
            entity.lastReadDate = Date()
            
            if let completed = didComplete {
                entity.isCompleted = completed
            }
            
            CoreDataStack.shared.saveContext()
        } catch {
            print("Error saving progress: \(error)")
        }
    }
    
    // MARK: - Checkpoint Logic
    func isCheckpointCompleted(storyId: String, checkpointText: String) -> Bool {
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
                    current += (current.isEmpty ? "" : ",") + checkId
                    entity.completedCheckpoints = current
                    CoreDataStack.shared.saveContext()
                }
            }
        } catch {
            print("Error saving checkpoint: \(error)")
        }
    }
    // MARK: - Dashboard Helpers (Updated for Navigation)
    func getLastActiveStoryDetails() -> (String, Bool)? {
        guard let (story, _, isNew) = getLastActiveStory() else { return nil }
        return (story.title, isNew)
    }
        
    func getLastActiveStory() -> (Story, Int, Bool)? {
        let context = CoreDataStack.shared.context
        let request: NSFetchRequest<StoryEntity> = StoryEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "lastReadDate", ascending: false)]
        request.fetchLimit = 1
        
        do {
            guard let lastEntity = try context.fetch(request).first,
                  let lastId = lastEntity.storyId else {
                if let first = getStories(for: "Level 1").first { return (first, 0, true) }
                return nil
            }
            
            if !lastEntity.isCompleted {
                if let story = findStory(for: lastId) {
                    return (story, Int(lastEntity.lastPageIndex), false)
                }
            }
            
            if let nextStory = findNextStory(after: lastId) {
                return (nextStory, 0, true)
            }
            
            if let story = findStory(for: lastId) {
                return (story, 0, false)
            }
            
        } catch { return nil }
        return nil
    }
        
    private func findStory(for storyId: String) -> Story? {
        for level in ["Level 1", "Level 2", "Level 3"] {
            if let match = getStories(for: level).first(where: { $0.id == storyId }) {
                return match
            }
        }
        return nil
    }
}
