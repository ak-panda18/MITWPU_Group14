import Foundation

final class SyllableEngine {

    // MARK: - Load CMUdict
    private static let cmu: [String: Int] = loadCMU()

    // MARK: - Load Hyphenation Patterns
    private static let hyphenator = Hyphenator()

    // MARK: - Public API
    static func syllabify(_ word: String) -> String {

        let clean = word.lowercased().filter { $0.isLetter }
        guard clean.count > 2 else { return word }

        if let override = SyllableOverrides.map[clean] {
            return override
        }

        return hyphenator.hyphenate(word)
    }

    // MARK: - Forced Split (SAFE fallback)
    private static func forceSplit(_ word: String, syllables: Int) -> String {

        let vowels = "aeiouy"
        var result: [String] = []
        var current = ""
        var vowelCount = 0

        for ch in word {
            current.append(ch)
            if vowels.contains(ch.lowercased()) {
                vowelCount += 1
                if vowelCount < syllables {
                    result.append(current)
                    current = ""
                }
            }
        }

        if !current.isEmpty {
            result.append(current)
        }

        return result.joined(separator: "-")
    }

    // MARK: - CMU Loader
    private static func loadCMU() -> [String: Int] {

        guard
            let url = Bundle.main.url(forResource: "cmudict", withExtension: "txt"),
            let data = try? String(contentsOf: url, encoding: .utf8)
        else {
            return [:]
        }

        var dict: [String: Int] = [:]
        let vowelRegex = try! NSRegularExpression(pattern: #"[AEIOU].*\d"#)

        for line in data.split(separator: "\n") {
            if line.hasPrefix(";;;") { continue }

            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count > 1 else { continue }

            let word = parts[0].lowercased()
            let phonemes = parts.dropFirst()

            let syllables = phonemes.filter {
                vowelRegex.firstMatch(
                    in: String($0),
                    range: NSRange(location: 0, length: $0.count)
                ) != nil
            }.count

            dict[word] = syllables
        }

        return dict
    }
}
