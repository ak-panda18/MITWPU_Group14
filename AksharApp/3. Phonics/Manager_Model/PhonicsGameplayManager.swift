import Foundation

class PhonicsGameplayManager {
    static let shared = PhonicsGameplayManager()
    
    // MARK: - Internal State
    private var cycle: RandomizedQuestionCycle?
    private var session: PhonicsSessionData?
    private var currentCycleKey: String = ""
    private var hasSavedSession = false
    
    private init() {}
    
    // MARK: - Setup
    
    func startSession(for exercise: ExerciseType, totalQuestions: Int, startPointer: Int) {
        self.hasSavedSession = false
        self.currentCycleKey = cycleKey(for: exercise)
        
        // Load existing cycle or create new one
        if let savedCycle = self.loadCycle(key: currentCycleKey) {
            self.cycle = savedCycle
        } else {
            self.cycle = RandomizedQuestionCycle(count: totalQuestions, startPointer: startPointer)
        }
        
        self.session = PhonicsSessionData(
            id: UUID(),
            date: Date(),
            childId: "default_child",
            exerciseType: exerciseKey(for: exercise),
            correctCount: 0,
            totalAttempts: 0,
            startTime: Date(),
            endTime: nil
        )
    }
    
    // MARK: - Game Loop
    
    func getCurrentIndex() -> Int {
        return cycle?.currentIndex() ?? 0
    }
    
    func advanceToNext() {
        cycle?.moveToNext()
        if let c = cycle {
            self.saveCycle(c, key: currentCycleKey)
        }
    }
    
    func recordSuccess() {
        session?.correctCount += 1
    }
    
    func recordAttempt() {
        session?.totalAttempts += 1
    }
    
    func getCyclePointer() -> Int {
        return cycle?.pointer ?? 0
    }
    
    // MARK: - Teardown
    
    func endSession() {
        guard !hasSavedSession, var s = session else { return }
        
        s.endTime = Date()
        AnalyticsStore.shared.appendPhonicsSession(s)
        hasSavedSession = true
    }
    
    func clearCycleProgress() {
        UserDefaults.standard.removeObject(forKey: currentCycleKey)
    }
    
    // MARK: - Internal Persistence
    
    private func saveCycle(_ cycle: RandomizedQuestionCycle, key: String) {
        if let data = try? JSONEncoder().encode(cycle) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadCycle(key: String) -> RandomizedQuestionCycle? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let cycle = try? JSONDecoder().decode(RandomizedQuestionCycle.self, from: data)
        else {
            return nil
        }
        return cycle
    }
    
    // MARK: - Helpers
    
    private func cycleKey(for type: ExerciseType) -> String {
        switch type {
        case .rhyme: return "rhyme_words_cycle"
        case .detective: return "sound_detector_cycle"
        case .quizMyStory: return "quiz_my_story_cycle"
        case .fluency: return "fluency_cycle"
        case .wordBuilder: return "word_builder_cycle"
        }
    }
    
    private func exerciseKey(for type: ExerciseType) -> String {
        switch type {
        case .rhyme: return "rhyme_words"
        case .detective: return "sound_detector"
        case .quizMyStory: return "quiz_my_story"
        case .fluency: return "fluency_drill"
        case .wordBuilder: return "word_builder"
        }
    }
}

// MARK: - Merged Helper Logic
// This struct is now internal to this file, so you can delete the separate file.
struct RandomizedQuestionCycle: Codable {
    private(set) var indices: [Int]
    private(set) var pointer: Int

    init(count: Int, startPointer: Int = 0) {
        self.indices = Array(0..<count)
        self.indices.shuffle()
        self.pointer = min(startPointer, count - 1)
    }

    func currentIndex() -> Int {
        indices[pointer]
    }

    mutating func moveToNext() {
        pointer += 1
        if pointer >= indices.count {
            indices.shuffle()
            pointer = 0
        }
    }
}
