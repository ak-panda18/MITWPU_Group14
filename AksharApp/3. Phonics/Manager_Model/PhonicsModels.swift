//
//  PhonicsModels.swift
//  AksharApp
//
//  Created by Akshita Panda on 14/02/26.
//

import Foundation

// MARK: - Fluency Drills
struct FluencyItem: Codable {
    let speakableText: String
}

// MARK: - Quiz My Story
struct QuizQuestion: Codable {
    let sentence: String
    let question: String
    let options: [String]
    let correctIndex: Int
}

// MARK: - Rhyme Words
struct RhymeQuestion: Codable {
    let targetWord: String
    let options: [String]
    let correctWords: [String]
}

// MARK: - Sound Detective
struct SoundQuestion: Codable {
    let word: String
    let correctInitial: String
    let options: [String]
    let imageName: String
}

// MARK: - Word Builder
struct WordBuilderQuestion: Codable {
    let imageName: String
    let tiles: [String]
    let correct: String

    var blanksCount: Int { tiles.count }
}
