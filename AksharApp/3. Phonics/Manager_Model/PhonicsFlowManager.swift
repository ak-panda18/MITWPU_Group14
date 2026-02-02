import Foundation

class PhonicsFlowManager {
    static let shared = PhonicsFlowManager()
    
    private let storageKey = "phonics_flow_state_v1"
    
    // State Variables
    private var isFirstRun: Bool = true
    private var currentIndex: Int = 0
    private var shuffledIndices: [Int] = []
    
    private init() {
        loadState()
    }
    
    // MARK: - Public API
    
    func getCurrentExercise() -> ExerciseType {
        let allExercises = ExerciseType.allCases
        
        if isFirstRun {
            // Mode 1: Sequential (0, 1, 2, 3, 4)
            // Safety check to ensure we don't crash if index is weird
            let safeIndex = clamp(currentIndex, max: allExercises.count - 1)
            return allExercises[safeIndex]
        } else {
            // Mode 2: Randomized
            if shuffledIndices.isEmpty {
                reshuffle()
            }
            let safePointer = clamp(currentIndex, max: shuffledIndices.count - 1)
            let typeIndex = shuffledIndices[safePointer]
            return allExercises[typeIndex]
        }
    }
    
    func advance() {
        let total = ExerciseType.allCases.count
        currentIndex += 1
        
        // Check if we finished the full set of 5
        if currentIndex >= total {
            finishCycle()
        } else {
            saveState()
        }
    }
    
    // MARK: - Private Logic
    
    private func finishCycle() {
        currentIndex = 0
        
        if isFirstRun {
            // Congratulations, you finished the sequential run!
            // Now switch to random mode forever.
            isFirstRun = false
        }
        
        // Prepare a new shuffle for the next cycle
        reshuffle()
        saveState()
    }
    
    private func reshuffle() {
        let total = ExerciseType.allCases.count
        shuffledIndices = Array(0..<total).shuffled()
    }
    
    private func clamp(_ value: Int, max: Int) -> Int {
        return Swift.max(0, Swift.min(value, max))
    }
    
    // MARK: - Persistence
    
    private func saveState() {
        let data: [String: Any] = [
            "isFirstRun": isFirstRun,
            "currentIndex": currentIndex,
            "shuffledIndices": shuffledIndices
        ]
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    private func loadState() {
        guard let data = UserDefaults.standard.dictionary(forKey: storageKey) else {
            // First time ever: Setup defaults
            reshuffle()
            return
        }
        
        if let firstRun = data["isFirstRun"] as? Bool { self.isFirstRun = firstRun }
        if let idx = data["currentIndex"] as? Int { self.currentIndex = idx }
        if let indices = data["shuffledIndices"] as? [Int] { self.shuffledIndices = indices }
    }
}
