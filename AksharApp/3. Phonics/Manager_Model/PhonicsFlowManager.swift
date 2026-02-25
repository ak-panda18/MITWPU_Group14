import Foundation

class PhonicsFlowManager {
    static let shared = PhonicsFlowManager()
    
    private let storageKey = "phonics_flow_state_v1"
    private var isFirstRun: Bool = true
    private var currentIndex: Int = 0
    private var shuffledIndices: [Int] = []
    
    init() {
        loadState()
    }
    
    // MARK: - Public API
    func getCurrentExercise() -> ExerciseType {
        let allExercises = ExerciseType.allCases
        
        if isFirstRun {
            let safeIndex = clamp(currentIndex, max: allExercises.count - 1)
            return allExercises[safeIndex]
        } else {
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
            isFirstRun = false
        }
        
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
            reshuffle()
            return
        }
        
        if let firstRun = data["isFirstRun"] as? Bool { self.isFirstRun = firstRun }
        if let idx = data["currentIndex"] as? Int { self.currentIndex = idx }
        if let indices = data["shuffledIndices"] as? [Int] { self.shuffledIndices = indices }
    }
}
