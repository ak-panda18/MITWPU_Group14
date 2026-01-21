//
//  QuizMyStory.swift
//  AksharApp
//
//  Created by SDC-USER on 10/12/25.
//
import Foundation

struct QuizQuestion: Codable {
    let sentence: String
    let question: String
    let options: [String]
    let correctIndex: Int
}

enum QuizQuestionLoader {
    static func loadQuestions() -> [QuizQuestion] {
        guard let url = Bundle.main.url(forResource: "QuizMyStoryQuestions", withExtension: "json") else {
            print("JSON file not found.")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([QuizQuestion].self, from: data)
        } catch {
            print("Failed to decode JSON:", error)
            return []
        }
    }
}

