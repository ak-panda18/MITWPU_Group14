import Foundation
import CoreData

extension AnalyticsStore {
    
    // MARK: - Writing Mappers
    func mapWritingToStruct(_ entity: WritingSessionEntity) -> WritingSessionData {
        return WritingSessionData(
            id: entity.id ?? UUID(),
            date: entity.date ?? Date(),
            childId: entity.childId ?? "default",
            lettersAccuracy: Int(entity.lettersAccuracy),
            wordsAccuracy: Int(entity.wordsAccuracy),
            numbersAccuracy: Int(entity.numbersAccuracy)
        )
    }
    
    // MARK: - Phonics Mappers
    func mapPhonicsToStruct(_ entity: PhonicsSessionEntity) -> PhonicsSessionData {
        return PhonicsSessionData(
            id: entity.id ?? UUID(),
            date: entity.date ?? Date(),
            childId: entity.childId ?? "default",
            exerciseType: entity.exerciseType ?? "",
            correctCount: Int(entity.correctCount),
            totalAttempts: Int(entity.totalAttempts),
            startTime: entity.startTime ?? Date(),
            endTime: entity.endTime
        )
    }
    
    // MARK: - Reading Mappers
    func mapReadingToStruct(_ entity: ReadingSessionEntity) -> ReadingSessionData {
        return ReadingSessionData(
            id: entity.id ?? UUID(),
            storyId: entity.storyId ?? "",
            childId: entity.childId ?? "default",
            startTime: entity.startTime ?? Date(),
            endTime: entity.endTime,
            levelUnlocked: Int(entity.levelUnlocked)
        )
    }
    
    func mapCheckpointResultToStruct(_ entity: CheckpointResultEntity) -> ReadingCheckpointResultData {
        return ReadingCheckpointResultData(
            id: entity.id ?? UUID(),
            date: entity.date ?? Date(),
            storyId: entity.storyId ?? "",
            childId: entity.childId ?? "default",
            accuracy: entity.accuracy,
            checkpointText: entity.checkpointText ?? ""
        )
    }
    
    // MARK: - Checkpoint Attempt Mappers
    func mapAttemptToStruct(_ entity: CheckpointAttemptEntity) -> CheckpointAttempt {
        // Convert comma-separated string back to array
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
}
