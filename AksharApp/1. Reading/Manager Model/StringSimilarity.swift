import UIKit

extension String {
    
    // MARK: - Linguistic Data
    private static let ignorableWords: Set<String> = [
        "a", "an", "the", "and", "but", "or", "so", "if", "because",
        "to", "of", "in", "on", "at", "by", "for", "from", "with", "up", "out",
        "it", "he", "she", "they", "we", "i", "you", "me", "my", "this", "that",
        "is", "am", "are", "was", "were", "be", "been",
        "has", "have", "had", "do", "does", "did",
        "can", "will", "would", "could", "should"
    ]

    // MARK: - Word Extraction Helpers
    var allWords: [String] {
        let clean = self
            .lowercased()
            .replacingOccurrences(of: "[^a-z\\s]", with: "", options: .regularExpression)
        
        return clean
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
    }
    
    var gradableWords: [String] {
        return self.allWords.filter { !String.ignorableWords.contains($0) }
    }
    
    // MARK: - Scoring & coloring
    func colored(matching spokenWords: [String], font: UIFont) -> NSAttributedString {
        let original = self
        let attributed = NSMutableAttributedString(string: original)
        let fullRange = NSRange(location: 0, length: (original as NSString).length)
        
        attributed.addAttributes([
            .font: font,
            .foregroundColor: UIColor.systemGray
        ], range: fullRange)

        let wordRegex = try! NSRegularExpression(pattern: "\\w+", options: [])
        let matches = wordRegex.matches(in: original, range: fullRange)
        
        var spokenIndex = 0
        
        for (i, match) in matches.enumerated() {
            let wordRange = match.range
            let wordText = (original as NSString).substring(with: wordRange)
            let cleanWord = wordText.lowercased()
            
            let searchLimit = min(spokenIndex + 5, spokenWords.count)
            var foundMatch = false
            var matchIndex = -1
            
            for j in spokenIndex..<searchLimit {
                if spokenWords[j].isPhoneticMatch(to: cleanWord) {
                    matchIndex = j
                    foundMatch = true
                    break
                }
            }
            
            if foundMatch {
                attributed.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: wordRange)
                spokenIndex = matchIndex + 1
            } else {
                if spokenIndex < spokenWords.count {
                    let currentSpoken = spokenWords[spokenIndex]
                    var isNextWordMatch = false
                    
                    if i + 1 < matches.count {
                        let nextRange = matches[i+1].range
                        let nextText = (original as NSString).substring(with: nextRange).lowercased()
                        if currentSpoken.isPhoneticMatch(to: nextText) {
                            isNextWordMatch = true
                        }
                    }
                    
                    if !isNextWordMatch {
                        attributed.addAttribute(.foregroundColor, value: UIColor.systemRed, range: wordRange)
                        spokenIndex += 1
                    }
                }
            }
        }
        return attributed
    }
    
    func isPhoneticMatch(to target: String) -> Bool {
        let s = self.lowercased()
        let t = target.lowercased()

        if s == t { return true }

        if (s.first == "w" && t.first == "v") || (s.first == "v" && t.first == "w") {
            let sDrop = s.dropFirst()
            let tDrop = t.dropFirst()
            if sDrop == tDrop { return true }
            if String(sDrop).levenshteinDistance(to: String(tDrop)) <= 1 { return true }
        }

        if s.hasPrefix(t) || t.hasPrefix(s) { return true }

        let distance = s.levenshteinDistance(to: t)
        let maxLen = max(s.count, t.count)
        guard maxLen > 0 else { return false }

        if t.hasPrefix("wh") {
            if s.hasPrefix("w") || s.hasPrefix("v") {
                if distance <= 2 { return true }
            }
        }

        let similarityScore = 1.0 - Double(distance) / Double(maxLen)
        
        if t.starts(with: "w") {
            if maxLen <= 4 && distance <= 1 { return true }
        }
        
        switch maxLen {
        case 1...3: return similarityScore >= 0.7
        case 4...6: return similarityScore >= 0.65
        default: return similarityScore >= 0.6
        }
    }

    func levenshteinDistance(to other: String) -> Int {
        let aChars = Array(self)
        let bChars = Array(other)
        let lenA = aChars.count
        let lenB = bChars.count

        if lenA == 0 { return lenB }
        if lenB == 0 { return lenA }

        var dp = Array(repeating: Array(repeating: 0, count: lenB + 1), count: lenA + 1)
        for i in 0...lenA { dp[i][0] = i }
        for j in 0...lenB { dp[0][j] = j }

        for i in 1...lenA {
            for j in 1...lenB {
                if aChars[i - 1] == bChars[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = Swift.min(
                        dp[i - 1][j] + 1,
                        dp[i][j - 1] + 1,
                        dp[i - 1][j - 1] + 1
                    )
                }
            }
        }
        return dp[lenA][lenB]
    }
}
