//
//  SoundDetective.swift
//  AksharApp
//

import Foundation

// MARK: - Model
struct SoundQuestion: Codable {
    let word: String
    let correctInitial: String
    let options: [String]
    let imageName: String
}

// MARK: - Loader (stateless, consistent)
enum SoundQuestionLoader {

    static func loadQuestions() -> [SoundQuestion] {
        guard let url = Bundle.main.url(
            forResource: "SoundQuestions",
            withExtension: "json"
        ) else {
            print("SoundQuestions.json not found")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(
                [SoundQuestion].self,
                from: data
            )
        } catch {
            print("Failed decoding SoundQuestions.json:", error)
            return []
        }
    }
}



