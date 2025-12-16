//
//  WordBuilder.swift
//  AksharApp
//

import Foundation

// MARK: - Model
struct WordBuilderQuestion: Codable {
    let imageName: String
    let tiles: [String]
    let correct: String

    var blanksCount: Int { tiles.count }
}

// MARK: - Loader
enum WordBuilderQuestionLoader {

    static func loadQuestions() -> [WordBuilderQuestion] {
        guard let url = Bundle.main.url(
            forResource: "WordBuilderQuestions",
            withExtension: "json"
        ) else {
            print("WordBuilderQuestions.json not found")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(
                [WordBuilderQuestion].self,
                from: data
            )
        } catch {
            print("Failed to decode WordBuilderQuestions:", error)
            return []
        }
    }
}



