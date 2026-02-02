//
//  WordsTrace.swift
//  AksharApp
//
//  Created by Akshita Panda on 13/01/26.
//
import Foundation

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
        guard let url = Bundle.main.url(
            forResource: "WordsTraceData",
            withExtension: "json"
        ) else {
            print("WordsTraceData.json not found")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(
                [TracingWord].self,
                from: data
            )
        } catch {
            print("Failed to decode WrdsTrace Data:", error)
            return []
        }
    }
}

extension Array where Element == TracingWord {
    func words(for category: String) -> [TracingWord] {
        self.filter { $0.category == category }
    }
}


