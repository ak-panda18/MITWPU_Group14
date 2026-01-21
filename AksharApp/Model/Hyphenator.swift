//
//  Hyphenator.swift
//  AksharApp
//
//  Created by SDC-USER on 09/01/26.
//
import Foundation

final class Hyphenator {

    private let patterns: [String: [Int]]

    init() {
        self.patterns = Hyphenator.loadPatterns()
    }

    func hyphenate(_ word: String) -> String {

        let clean = word.lowercased().filter { $0.isLetter }
        guard clean.count > 4 else { return word }

        let points = hyphenationPoints(for: clean)
        return merge(original: word, points: points)
    }

    // MARK: - Liang Algorithm
    private func hyphenationPoints(for word: String) -> [Bool] {

        let padded = "." + word + "."
        let chars = Array(padded)
        var scores = Array(repeating: 0, count: chars.count)

        for i in 0..<chars.count {
            for j in i+1...chars.count {
                let slice = String(chars[i..<j])
                if let pattern = patterns[slice] {
                    for k in 0..<pattern.count {
                        let idx = i + k
                        if idx < scores.count {
                            scores[idx] = max(scores[idx], pattern[k])
                        }
                    }
                }
            }
        }

        return scores.map { $0 % 2 == 1 }
    }

    // MARK: - Merge
    private func merge(original: String, points: [Bool]) -> String {

        var result = ""
        let letters = Array(original)

        for i in 0..<letters.count {
            result.append(letters[i])

            // Liang rule: no breaks in first 2 / last 2 letters
            if i >= 2,
               i + 3 < points.count,
               points[i + 2] {
                result.append("-")
            }
        }

        return result
    }

    // MARK: - Pattern Loader
    private static func loadPatterns() -> [String: [Int]] {

        guard
            let url = Bundle.main.url(forResource: "hyphenation_en", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let raw = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            print("Failed to load hyphenation_en.json")
            return [:]
        }

        var result: [String: [Int]] = [:]

        for (pattern, _) in raw {

            let letters = pattern.filter { $0.isLetter }
            var values = Array(repeating: 0, count: letters.count + 1)

            var letterIndex = 0

            for char in pattern {
                if let n = char.wholeNumberValue {
                    if letterIndex < values.count {
                        values[letterIndex] = n
                    }
                } else if char.isLetter {
                    letterIndex += 1
                }
            }

            result[letters] = values
        }

        print("Loaded hyphenation patterns:", result.count)
        return result
    }
}

