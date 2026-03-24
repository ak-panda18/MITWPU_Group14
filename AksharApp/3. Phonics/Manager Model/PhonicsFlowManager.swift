import Foundation

// MARK: - Persisted state
private struct PhonicsFlowState: Codable {
    var isFirstRun:      Bool
    var currentIndex:    Int
    var shuffledIndices: [Int]
}

final class PhonicsFlowManager {

    private let storageKey = "phonics_flow_state_v2"
    private var state: PhonicsFlowState

    init() {
        if let data  = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(PhonicsFlowState.self, from: data) {
            state = saved
        } else {
            state = PhonicsFlowState(
                isFirstRun:      true,
                currentIndex:    0,
                shuffledIndices: Array(0..<ExerciseType.allCases.count).shuffled()
            )
        }
    }

    // MARK: - Public API
    func getCurrentExercise() -> ExerciseType {
        let all = ExerciseType.allCases
        if state.isFirstRun {
            return all[clamp(state.currentIndex, max: all.count - 1)]
        } else {
            if state.shuffledIndices.isEmpty { reshuffle() }
            return all[state.shuffledIndices[clamp(state.currentIndex, max: state.shuffledIndices.count - 1)]]
        }
    }

    func advance() {
        state.currentIndex += 1
        if state.currentIndex >= ExerciseType.allCases.count {
            finishCycle()
        } else {
            saveState()
        }
    }

    // MARK: - Private
    private func finishCycle() {
        state.currentIndex = 0
        state.isFirstRun   = false
        reshuffle()
        saveState()
    }

    private func reshuffle() {
        state.shuffledIndices = Array(0..<ExerciseType.allCases.count).shuffled()
    }

    private func clamp(_ value: Int, max: Int) -> Int {
        Swift.max(0, Swift.min(value, max))
    }

    private func saveState() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
