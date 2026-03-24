import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AksharApp", category: "TracingWordLoader")

// MARK: - Model
struct TracingWord: Codable {
    let category: String
    let word: String
    let wordImageName: String
    let imageName: String?
}

// MARK: - Loader
enum TracingWordLoader {

    static func loadWords() -> [TracingWord] {
        guard let url = Bundle.main.url(forResource: "WordsTraceData", withExtension: "json") else {
            logger.error("TracingWordLoader: WordsTraceData.json not found in bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([TracingWord].self, from: data)
        } catch {
            logger.error("TracingWordLoader: failed to decode WordsTraceData.json – \(error)")
            return []
        }
    }
}

extension Array where Element == TracingWord {
    func words(for category: String) -> [TracingWord] {
        self.filter { $0.category == category }
    }
}
