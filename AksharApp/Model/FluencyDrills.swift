//
//  FluencyDrills.swift
//  AksharApp
//
//  Created by SDC-USER on 10/12/25.
//
import Foundation

// MARK: - Model

struct FluencyItem: Codable {
    let speakableText: String
}

// MARK: - Loader

enum FluencyWordsLoader {
    
    static func loadWords() -> [FluencyItem] {
        guard let url = Bundle.main.url(forResource: "FluencyDrillsQuestions", withExtension: "json") else {
            print("FluencyDrillsQuestions.json not found in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let items = try decoder.decode([FluencyItem].self, from: data)
            return items
        } catch {
            print("Failed to load FluencyDrillsQuestions.json:", error)
            return []
        }
    }
}

