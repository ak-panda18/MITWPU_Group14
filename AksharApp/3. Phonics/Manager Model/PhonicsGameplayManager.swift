import Foundation

final class PhonicsGameplayManager {

    // MARK: - Dependencies
    private let analyticsStore: AnalyticsStore
    private let childManager: ChildManager

    // MARK: - State
    private var cycle: RandomizedQuestionCycle?
    private var session: PhonicsSessionData?
    private var currentCycleKey: String = ""
    private var hasSavedSession = false

    // MARK: - Init
    init(analyticsStore: AnalyticsStore, childManager: ChildManager) {
        self.analyticsStore = analyticsStore
        self.childManager   = childManager
    }

    // MARK: - Session Lifecycle
    func startSession(for exercise: ExerciseType, totalQuestions: Int, startPointer: Int) {
        hasSavedSession  = false
        currentCycleKey  = exercise.cycleKey

        cycle = loadCycle(key: currentCycleKey)
            ?? RandomizedQuestionCycle(count: totalQuestions, startPointer: startPointer)

        session = PhonicsSessionData(
            id: UUID(),
            date: Date(),
            childId: childManager.currentChild.id?.uuidString ?? "unknown",
            exerciseType: exercise.exerciseKey,
            correctCount: 0,
            totalAttempts: 0,
            startTime: Date(),
            endTime: nil
        )
    }

    func endSession() {
        guard !hasSavedSession, var s = session else { return }
        s.endTime = Date()
        analyticsStore.appendPhonicsSession(s)
        hasSavedSession = true
    }

    func clearCycleProgress() {
        UserDefaults.standard.removeObject(forKey: currentCycleKey)
    }

    // MARK: - Game Loop
    func getCurrentIndex() -> Int {
        return cycle?.currentIndex() ?? 0
    }

    func getCyclePointer() -> Int {
        return cycle?.pointer ?? 0
    }

    func advanceToNext() {
        cycle?.moveToNext()
        if let c = cycle { saveCycle(c, key: currentCycleKey) }
    }

    func recordSuccess() { session?.correctCount += 1 }
    func recordAttempt() { session?.totalAttempts += 1 }

    // MARK: - Persistence
    private func saveCycle(_ cycle: RandomizedQuestionCycle, key: String) {
        if let data = try? JSONEncoder().encode(cycle) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadCycle(key: String) -> RandomizedQuestionCycle? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let cycle = try? JSONDecoder().decode(RandomizedQuestionCycle.self, from: data)
        else { return nil }
        return cycle
    }
}

// MARK: - RandomizedQuestionCycle
struct RandomizedQuestionCycle: Codable {
    private(set) var indices: [Int]
    private(set) var pointer: Int

    init(count: Int, startPointer: Int = 0) {
        indices = Array(0..<count).shuffled()
        pointer = min(startPointer, max(count - 1, 0))
    }

    func currentIndex() -> Int { indices[pointer] }

    mutating func moveToNext() {
        pointer += 1
        if pointer >= indices.count {
            indices.shuffle()
            pointer = 0
        }
    }
}
