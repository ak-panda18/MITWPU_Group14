//
//  RhymeWords.swift
//  AksharApp
//
//  Created by SDC-USER on 10/12/25.
//

import Foundation

// MARK: - Model

struct RhymeQuestion: Codable {
    let targetWord: String
    let options: [String]
    let correctWords: [String]
}

// MARK: - Loader

enum RhymeQuestionLoader {
    static func loadQuestions() -> [RhymeQuestion] {
        guard let url = Bundle.main.url(forResource: "RhymeWordsQuestions", withExtension: "json") else {
            print("Could not find RhymeWordsQuestions.json in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let questions = try decoder.decode([RhymeQuestion].self, from: data)
            return questions
        } catch {
            print("Failed to decode RhymeWordsQuestions.json:", error)
            return []
        }
    }
}
