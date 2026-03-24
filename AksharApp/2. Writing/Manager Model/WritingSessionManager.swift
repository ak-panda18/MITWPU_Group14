import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AksharApp", category: "WritingSessionManager")

final class WritingSessionManager {

    private let analyticsStore: AnalyticsStore
    private let childManager:   ChildManager
    private let progressStore:  WritingProgressStore

    private(set) var sessionMistakes: Int = 0

    init(analyticsStore: AnalyticsStore,
         childManager: ChildManager,
         progressStore: WritingProgressStore) {
        self.analyticsStore = analyticsStore
        self.childManager   = childManager
        self.progressStore  = progressStore
    }

    // MARK: - Session Lifecycle
    func startNewSession() {
        sessionMistakes = 0
    }

    func trackMistake(index: Int, category: String) {
        sessionMistakes += 1
    }

    func didEarnSticker() -> Bool {
        return sessionMistakes <= 2
    }

    // MARK: - Finalize
    func finalizeSession(index: Int,
                         category: String,
                         mistakes: Int,
                         contentType: WritingContentType?,
                         tracingCategory: TracingCategory? = nil) {

        let sessionScore = Int((1.0 / Double(mistakes + 1)) * 100.0)

        let allSessions = analyticsStore.fetchWritingSessions()
        let relevant: [WritingSessionData] = {
            switch contentType {
            case .letters: return allSessions.filter { $0.lettersAccuracy > 0 }
            case .numbers: return allSessions.filter { $0.numbersAccuracy > 0 }
            default:       return allSessions.filter { $0.wordsAccuracy   > 0 }
            }
        }()

        let finalScore: Int = {
            guard !relevant.isEmpty else { return sessionScore }
            let prevTotal = relevant.reduce(0) { sum, s -> Int in
                switch contentType {
                case .letters: return sum + s.lettersAccuracy
                case .numbers: return sum + s.numbersAccuracy
                default:       return sum + s.wordsAccuracy
                }
            }
            let prevAvg = prevTotal / relevant.count
            return Int(
                (Double(prevAvg * relevant.count) + Double(sessionScore))
                / Double(relevant.count + 1)
            )
        }()

        let session = WritingSessionData(
            id: UUID(),
            date: Date(),
            childId: childManager.currentChild.id?.uuidString ?? "default",
            lettersAccuracy: contentType == .letters  ? finalScore : 0,
            wordsAccuracy:   tracingCategory != nil   ? finalScore : 0,
            numbersAccuracy: contentType == .numbers  ? finalScore : 0
        )

        analyticsStore.appendWritingSession(session)
        sessionMistakes = 0

        logger.debug("WritingSessionManager: session finalized. Score: \(finalScore)")
    }
}
