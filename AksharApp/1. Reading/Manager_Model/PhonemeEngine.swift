import Foundation

final class PhonemeEngine {
    
    // MARK: - Linguistic Rules
    private static let prefixes = [
        "un", "re", "dis", "mis", "pre", "im", "in", "non", "over", "under"
    ]

    private static let phonemeMap: [String: String] = [
        "ER": "ur", "IH": "i", "IY": "ee", "AE": "a", "AA": "a", "AO": "aw",
        "AH": "uh", "UH": "u", "NG": "ng", "SH": "sh", "CH": "ch", "TH": "th",
        "W": "w", "K": "k", "G": "g", "R": "r", "L": "l", "M": "m", "N": "n",
        "P": "p", "B": "b", "D": "d", "T": "t", "F": "f", "S": "s", "Z": "z"
    ]
    
    private static let morphologySuffixes = [
        "ing", "ed", "ly", "er", "est", "ness", "ment", "ful", "less", "tion", "sion"
    ]
    
    private static let kindleExceptions: [String: String] = [
        "little": "lit·tle", "people": "peo·ple", "because": "be·cause",
        "every": "ev·ery", "different": "dif·fer·ent", "animal": "an·i·mal",
        "family": "fam·i·ly", "again": "a·gain", "water": "wa·ter", "mother": "moth·er"
    ]
    
    private static let overrides: [String: String] = [
        "harvesting": "har-vest-ing", "harvest": "har-vest",
        "working": "work-ing", "work": "work",
        "planting": "plan-ting", "planted": "plan-ted",
        "grinding": "grind-ing", "grind": "grind",
        "reading": "read-ing", "writing": "writ-ing",
        "written": "writ-ten"
    ]
    
    // MARK: - Dictionaries
    private static let custom: [String: [String]] = BundleDataLoader.shared.load("PhonemeDictionary", as: [String: [String]].self)

    private static let cmu: [String: [String]] = loadCMU()

    // MARK: - Public API
    static func kindleSplit(_ word: String) -> String {
        let clean = word.lowercased().filter { $0.isLetter }

        if let override = overrides[clean] {
            return override
        }
        if let exception = kindleExceptions[clean] {
            return exception
        }
        if let prefix = prefixSplit(clean) {
            return prefix
        }
        if let morph = morphologySplit(clean) {
            return morph
        }
        return phonemeFallback(clean)
    }

    // MARK: - Private Algorithms
    private static func prefixSplit(_ word: String) -> String? {
        for prefix in prefixes {
            if word.hasPrefix(prefix) && word.count > prefix.count + 3 {
                let rest = String(word.dropFirst(prefix.count))
                return prefix + "·" + rest
            }
        }
        return nil
    }

    private static func morphologySplit(_ word: String) -> String? {
        for suffix in morphologySuffixes {
            if word.hasSuffix(suffix) && word.count > suffix.count + 2 {
                var base = String(word.dropLast(suffix.count))

                if base.hasSuffix("e") && suffix == "ing" {
                    base.removeLast()
                }

                if base.count > 2 {
                    let last = base.last!
                    let secondLast = base.dropLast().last!
                    if last == secondLast {
                        base.removeLast()
                    }
                }
                return base + "·" + suffix
            }
        }
        return nil
    }

    private static func phonemeFallback(_ word: String) -> String {
        var phonemes: [String]?

        if let customDictPhonemes = custom[word] {
            phonemes = customDictPhonemes
        } else if let cmuDictPhonemes = cmu[word] {
            phonemes = cmuDictPhonemes
        }

        guard let ph = phonemes else { return word }

        let readable = ph.map {
            let base = $0.replacingOccurrences(of: "[0-9]", with: "", options: .regularExpression)
            return phonemeMap[base] ?? base.lowercased()
        }

        return chunkReadable(readable)
    }

    private static func chunkReadable(_ sounds: [String]) -> String {
        guard !sounds.isEmpty else { return "" }

        var chunks: [String] = []
        var currentChunk = sounds[0]

        for i in 1..<sounds.count {
            let sound = sounds[i]

            if sound == "ng" || sound == "sh" || sound == "ch" || sound == "th" {
                chunks.append(currentChunk)
                currentChunk = sound
                continue
            }

            if isConsonant(sound) && containsVowel(currentChunk) {
                chunks.append(currentChunk)
                currentChunk = sound
            } else {
                currentChunk += sound
            }
        }
        chunks.append(currentChunk)
        return chunks.joined(separator: "·")
    }

    private static func containsVowel(_ text: String) -> Bool {
        let vowels = ["a","e","i","o","u","ee","ur","aw","uh"]
        return vowels.contains { text.contains($0) }
    }

    private static func isConsonant(_ sound: String) -> Bool {
        let vowels = ["a","e","i","o","u","ee","ur","aw","uh"]
        return !vowels.contains(sound)
    }

    // MARK: - Load CMUdict Full Phonemes
    private static func loadCMU() -> [String: [String]] {
        guard
            let url = Bundle.main.url(forResource: "cmudict", withExtension: "txt"),
            let text = try? String(contentsOf: url)
        else { return [:] }

        var result: [String: [String]] = [:]

        for line in text.split(separator: "\n") {
            if line.hasPrefix(";;;") { continue }

            let parts = line.split(separator: " ")
            guard parts.count > 2 else { continue }

            let word = parts[0].lowercased()
            let phonemes = parts.dropFirst().map { String($0) }
            result[word] = phonemes
        }
        return result
    }
}
