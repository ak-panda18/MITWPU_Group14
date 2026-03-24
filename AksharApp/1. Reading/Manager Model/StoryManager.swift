import Foundation
import CoreData

final class StoryManager {

    // MARK: - Sub-stores
    let repository:     StoryRepository
    let progressStore:  ReadingProgressStore
    let analyticsStore: AnalyticsStore

    init(repository: StoryRepository,
         progressStore: ReadingProgressStore,
         analyticsStore: AnalyticsStore) {
        self.repository     = repository
        self.progressStore  = progressStore
        self.analyticsStore = analyticsStore
    }

    // MARK: - Reading Session
    func startReadingSession(storyId: String, childId: String, level: Int) -> ReadingSessionData {
        let session = ReadingSessionData(
            id: UUID(),
            storyId: storyId,
            childId: childId,
            startTime: Date(),
            endTime: nil,
            levelUnlocked: level
        )
        analyticsStore.appendReadingSession(session)
        return session
    }

    func endReadingSession(_ session: ReadingSessionData) {
        guard session.endTime == nil else { return }
        analyticsStore.updateReadingSessionEnd(sessionId: session.id, endTime: Date())
    }

    // MARK: - Story Retrieval
    func getStories(for difficulty: String) -> [Story] { repository.stories(for: difficulty) }
    func getStory(by id: String)             -> Story?  { repository.story(by: id) }
    func getRandomStory()                    -> Story?  { repository.randomStory() }
    func findNextStory(after id: String)     -> Story?  { repository.nextStory(after: id) }

    func getCheckpointItem(storyId: String, pageNumber: Int) -> CheckpointItem? {
        repository.checkpointItem(storyId: storyId, pageNumber: pageNumber)
    }

    // MARK: - Progress
    func getProgress(for storyId: String) -> (Int, Bool) { progressStore.getProgress(for: storyId) }

    func saveProgress(storyId: String, pageIndex: Int, didComplete: Bool? = nil) {
        progressStore.saveProgress(storyId: storyId, pageIndex: pageIndex, didComplete: didComplete)
    }

    func isCheckpointCompleted(storyId: String, checkpointText: String) -> Bool {
        progressStore.isCheckpointCompleted(storyId: storyId, checkpointText: checkpointText)
    }

    func markCheckpointCompleted(storyId: String, checkpointText: String) {
        progressStore.markCheckpointCompleted(storyId: storyId, checkpointText: checkpointText)
    }

    // MARK: - Index to Highlight
    func indexToHighlight(for difficulty: String) -> Int? {
        let stories = getStories(for: difficulty)
        for (i, s) in stories.enumerated() {
            let (saved, done) = getProgress(for: s.id)
            if !done && saved > 0 { return i }
        }
        for (i, s) in stories.enumerated() {
            let (_, done) = getProgress(for: s.id)
            if !done { return i }
        }
        return nil
    }

    // MARK: - Dashboard Helpers
    func getLastActiveStoryDetails() -> (String, Bool)? {
        guard let (story, _, isNew) = getLastActiveStory() else { return nil }
        return (story.title, isNew)
    }

    func getLastActiveStory() -> (Story, Int, Bool)? {
        guard let lastEntity = progressStore.lastReadEntity(),
              let lastId     = lastEntity.storyId else {
            if let first = getStories(for: "Level 1").first { return (first, 0, true) }
            return nil
        }

        if !lastEntity.isCompleted,
           let story = repository.findStory(for: lastId) {
            return (story, Int(lastEntity.lastPageIndex), false)
        }

        if let next = findNextStory(after: lastId) {
            return (next, 0, true)
        }

        if let story = repository.findStory(for: lastId) {
            return (story, 0, false)
        }

        return nil
    }
}
