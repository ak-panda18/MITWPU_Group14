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
// MARK: - Analytics Aggregation Layer

struct AnalyticsAggregator {

    // MARK: - Writing
    static func latestScore(
        from sessions: [WritingSessionData],
        contentType: WritingContentType
    ) -> Int? {

        let filtered: [WritingSessionData]

        switch contentType {

        case .letters:
            filtered = sessions.filter { $0.lettersAccuracy > 0 }

        case .words:
            filtered = sessions.filter { $0.wordsAccuracy > 0 }

        case .numbers:
            filtered = sessions.filter { $0.numbersAccuracy > 0 }
        }

        guard let latest = filtered.sorted(by: { $0.date > $1.date }).first else {
            return nil
        }

        switch contentType {

        case .letters:
            return latest.lettersAccuracy

        case .words:
            return latest.wordsAccuracy

        case .numbers:
            return latest.numbersAccuracy
        }
    }

    static func delta(current: Int?, previous: Int?) -> Int? {
        guard let current, let previous else { return nil }
        return current - previous
    }

    static func writingGraphData(
        sessions: [WritingSessionData],
        keyPath: KeyPath<WritingSessionData, Int>,
        isWeekly: Bool
    ) -> [AccuracyPoint] {

        let relevant = sessions.filter { $0[keyPath: keyPath] > 0 }
        let calendar = Calendar.current

        let groupKey: (Date) -> Date = { date in
            if isWeekly {
                return calendar.startOfDay(for: date)
            } else {
                return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            }
        }

        let grouped = Dictionary(grouping: relevant) {
            groupKey($0.date)
        }

        let sortedDates = grouped.keys.sorted()

        return sortedDates.map { date in
            let sessionsInGroup = grouped[date]!
            let total = sessionsInGroup.reduce(0) { $0 + $1[keyPath: keyPath] }
            let avg = total / sessionsInGroup.count

            let formatter = DateFormatter()
            formatter.dateFormat = isWeekly ? "E" : "d MMM"

            return AccuracyPoint(
                dateLabel: formatter.string(from: date),
                value: avg
            )
        }
    }

    // MARK: - Phonics

    static func phonicsOverview(
        sessions: [PhonicsSessionData]
    ) -> (sound: Int?, quiz: Int?, rhyme: Int?, word: Int?, fluency: Int?, hasData: Bool) {

        guard !sessions.isEmpty else {
            return (nil, nil, nil, nil, nil, false)
        }

        func accuracy(type: String) -> Int? {
            let filtered = sessions.filter { $0.exerciseType == type }

            let totalCorrect = filtered.reduce(0) { $0 + $1.correctCount }
            let totalAttempts = filtered.reduce(0) { $0 + $1.totalAttempts }

            guard totalAttempts > 0 else { return nil } 

            return Int((Double(totalCorrect) / Double(totalAttempts)) * 100)
        }

        let fluencySessions = sessions.filter { $0.exerciseType == "fluency_drill" }

        let totalCorrect = fluencySessions.reduce(0) { $0 + $1.correctCount }
        let totalDuration = fluencySessions.reduce(0.0) { result, session in
            guard let end = session.endTime else { return result }
            return result + end.timeIntervalSince(session.startTime)
        }

        let minutes = totalDuration / 60
        let fluency: Int? = minutes > 0 ? Int(Double(totalCorrect) / minutes) : nil

        return (
            accuracy(type: "sound_detector"),
            accuracy(type: "quiz_my_story"),
            accuracy(type: "rhyme_words"),
            accuracy(type: "word_builder"),
            fluency,
            true
        )
    }
    // MARK: - Reading Checkpoint Aggregation

    static func weeklyCheckpointStats(
        attempts: [CheckpointAttempt]
    ) -> [DailyStats] {

        var groupedData: [Date: [Int]] = [:]
        let calendar = Calendar.current

        for attempt in attempts {
            let dateKey = calendar.startOfDay(for: attempt.timestamp)
            groupedData[dateKey, default: []].append(attempt.accuracy)
        }

        let sortedDates = groupedData.keys.sorted(by: { $0 > $1 })

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"

        let processed = sortedDates.map { date -> DailyStats in
            let scores = groupedData[date] ?? []
            let average = scores.reduce(0, +) / scores.count
            return DailyStats(
                date: date,
                accuracy: average,
                formattedDate: formatter.string(from: date)
            )
        }

        return Array(processed.prefix(7))
    }

    static func monthlyCheckpointStats(
        attempts: [CheckpointAttempt]
    ) -> [DailyStats] {

        let calendar = Calendar.current
        let now = Date()

        var weeklyBuckets: [[Int]] = [[], [], [], []]

        for attempt in attempts {
            guard let daysAgo = calendar.dateComponents([.day],
                                                        from: attempt.timestamp,
                                                        to: now).day else { continue }

            switch daysAgo {
            case 0..<7:
                weeklyBuckets[3].append(attempt.accuracy)
            case 7..<14:
                weeklyBuckets[2].append(attempt.accuracy)
            case 14..<21:
                weeklyBuckets[1].append(attempt.accuracy)
            case 21..<28:
                weeklyBuckets[0].append(attempt.accuracy)
            default:
                break
            }
        }

        let labels = ["3 Weeks Ago", "2 Weeks Ago", "Last Week", "This Week"]

        var result: [DailyStats] = []

        for i in 0..<4 {
            let scores = weeklyBuckets[i]
            guard !scores.isEmpty else { continue }

            let average = scores.reduce(0, +) / scores.count

            result.append(
                DailyStats(
                    date: now,
                    accuracy: average,
                    formattedDate: labels[i]
                )
            )
        }

        return result
    }


}
