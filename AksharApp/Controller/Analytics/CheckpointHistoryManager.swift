import Foundation

class CheckpointHistoryManager {
    
    // MARK: - Singleton
    static let shared = CheckpointHistoryManager()
    private init() {}
    
    // MARK: - Constants
    private let fileName = "checkpoint_history.json"
    
    // MARK: - File Path Helpers
    private func getFileURL() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(fileName)
    }
    
    // MARK: - Fetching History
    func getAllAttempts() -> [CheckpointAttempt] {
        let url = getFileURL()
        
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        
        do {
            let data = try Data(contentsOf: url)
            let attempts = try JSONDecoder().decode([CheckpointAttempt].self, from: data)
            return attempts
        } catch {
            print("Error loading history: \(error)")
            return []
        }
    }
    
    // MARK: - Saving History
    func save(attempt: CheckpointAttempt) {
        var currentHistory = getAllAttempts()
        currentHistory.insert(attempt, at: 0)
        do {
            let data = try JSONEncoder().encode(currentHistory)
            try data.write(to: getFileURL())
            print("Saved attempt to JSON file")
        } catch {
            print("Error saving history: \(error)")
        }
    }
}
