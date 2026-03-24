import Foundation

struct AnalyticsData: Codable {
    var readingSessions: [ReadingSessionData]
    var readingCheckpointResults: [ReadingCheckpointResultData]
    var phonicsSessions: [PhonicsSessionData]
    var writingSessions: [WritingSessionData]

    static let empty = AnalyticsData(
        readingSessions: [],
        readingCheckpointResults: [],
        phonicsSessions: [],
        writingSessions: []
    )
}

struct ReadingSessionData: Codable, Identifiable {
    let id: UUID
    let storyId: String
    let childId: String
    var totalDuration: TimeInterval = 0
    let startTime: Date
    var endTime: Date?
    
    let levelUnlocked: Int
}

struct ReadingCheckpointResultData: Codable, Identifiable {
    let id: UUID
    let date: Date

    let storyId: String
    let childId: String

    let accuracy: Double

    let checkpointText: String
}

struct PhonicsSessionData: Codable, Identifiable {
    let id: UUID
    let date: Date

    let childId: String
    let exerciseType: String

    var correctCount: Int
    var totalAttempts: Int

    var startTime: Date
    var endTime: Date?
}

struct WritingSessionData: Codable, Identifiable {
    let id: UUID
    let date: Date
    
    let childId: String
    
    let lettersAccuracy: Int
    let wordsAccuracy: Int
    let numbersAccuracy: Int
}


struct CheckpointAttempt: Codable {
    let storyTitle: String
    let checkpointNumber: Int
    let accuracy: Int
    let spokenWords: [String]
    let timestamp: Date
}

struct DailyStats: Codable {
    let date: Date
    let accuracy: Int
    let formattedDate: String
}
