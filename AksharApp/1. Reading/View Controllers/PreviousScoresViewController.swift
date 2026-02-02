import UIKit

// MARK: - Custom Cell Class
class PreviousScoreCell: UICollectionViewCell {
    
    // MARK: - outlets
    @IBOutlet weak var coloredTextLabel: UILabel!
    @IBOutlet weak var scoreView: UIView!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var AttemptParentView: UIView!
    

    // MARK: - Properties
    private let bottomBorder = CALayer()
    
    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        coloredTextLabel.numberOfLines = 0
        coloredTextLabel.textColor = .label

        scoreLabel.layer.borderWidth = 2.0
        scoreLabel.layer.cornerRadius = 50
        scoreLabel.clipsToBounds = true

        bottomBorder.backgroundColor = UIColor.systemGray3.cgColor
        AttemptParentView.layer.addSublayer(bottomBorder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let borderHeight: CGFloat = 1.0
        let width = AttemptParentView.bounds.width
        let height = AttemptParentView.bounds.height
        bottomBorder.frame = CGRect(x: 0, y: height - borderHeight, width: width, height: borderHeight)
    }
}

// MARK: - PreviousScoresViewController
class PreviousScoresViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    // MARK: - Outlets
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var titleView: UIView!
    
    // MARK: - Properties
    var targetStoryTitle: String = ""
    var targetCheckpointNumber: Int = 0
    var originalText: String = ""
    
    private var attempts: [CheckpointAttempt] = []
    
//    private let ignorableWords: Set<String> = [
//        "a", "an", "the",
//        "and", "but", "or", "so", "if", "because",
//        "to", "of", "in", "on", "at", "by", "for", "from", "with", "up", "out",
//        "it", "he", "she", "they", "we", "i", "you", "me", "my", "this", "that",
//        "is", "am", "are", "was", "were", "be", "been",
//        "has", "have", "had", "do", "does", "did",
//        "can", "will", "would", "could", "should"
//    ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadFilteredHistory()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let label = view.viewWithTag(101) as? UILabel {
            label.addBottomBorder(color: .systemGray4)
        }
    }

    // MARK: - Setup
    private func setupUI() {
        collectionView.dataSource = self
        collectionView.delegate = self
        view.backgroundColor = .systemBackground

        titleView.layer.borderColor = UIColor.systemYellow.cgColor
        titleView.layer.borderWidth = 2
        titleView.layer.cornerRadius = 25

        titleLabel.text = "Last Attempt Score"
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)

        collectionView.layer.cornerRadius = 20
        collectionView.layer.borderColor = UIColor.systemYellow.cgColor
        collectionView.layer.borderWidth = 2
        
        collectionView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        
    }
    private func loadFilteredHistory() {
        let allHistory = CheckpointHistoryManager.shared.getAllAttempts()
        let filtered = allHistory.filter { $0.storyTitle == self.targetStoryTitle && $0.checkpointNumber == self.targetCheckpointNumber }
        let sorted = filtered.sorted { $0.timestamp > $1.timestamp }
        
        if let lastAttempt = sorted.first {
            self.attempts = [lastAttempt]
        }
        collectionView.reloadData()
    }

    // MARK: - Collection View
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return attempts.count
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return .zero
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PreviousScoreCell", for: indexPath) as? PreviousScoreCell else {
                return UICollectionViewCell()
            }

            let attempt = attempts[indexPath.row]
            cell.scoreLabel.text = "\(attempt.accuracy)%"
            
            let statusColor: UIColor = attempt.accuracy >= 95 ? .systemGreen : (attempt.accuracy >= 50 ? .systemOrange : .systemRed)
            cell.scoreLabel.textColor = statusColor
            cell.scoreLabel.layer.borderColor = statusColor.cgColor

            // USE THE NEW METHOD WITH FONT
            // Assuming your cell label usually uses system font size 17 or similar.
            // You can pass 'cell.coloredTextLabel.font' if you want to keep the storyboard font.
            cell.coloredTextLabel.attributedText = originalText.colored(
                matching: attempt.spokenWords,
                font: cell.coloredTextLabel.font
            )
            
            return cell
        }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - 40
        let height = collectionView.bounds.height - 40
        return CGSize(width: width, height: height)
    }

//    private func generateColoredString(original: String, spokenWords: [String]) -> NSAttributedString {
//            let attributed = NSMutableAttributedString(string: original)
//            let fullRange = NSRange(location: 0, length: (original as NSString).length)
//            attributed.addAttributes([.font: UIFont.systemFont(ofSize: 26), .foregroundColor: UIColor.systemGray], range: fullRange)
//
//            let wordRegex = try! NSRegularExpression(pattern: "\\w+", options: [])
//            let matches = wordRegex.matches(in: original, range: fullRange)
//            
//            var spokenIndex = 0
//            
//            for (i, match) in matches.enumerated() {
//                let wordRange = match.range
//                let wordText = (original as NSString).substring(with: wordRange)
//                let cleanWord = wordText.lowercased()
//                let searchLimit = min(spokenIndex + 5, spokenWords.count)
//                var foundMatch = false
//                var matchIndex = -1
//                
//                for j in spokenIndex..<searchLimit {
//                    if isRelaxedMatch(spoken: spokenWords[j], target: cleanWord) {
//                        matchIndex = j
//                        foundMatch = true
//                        break
//                    }
//                }
//                
//                if foundMatch {
//                    attributed.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: wordRange)
//                    spokenIndex = matchIndex + 1
//                } else {
//                    if spokenIndex < spokenWords.count {
//                        let currentSpoken = spokenWords[spokenIndex]
//                        var isNextWord = false
//                        if i + 1 < matches.count {
//                            let nextRange = matches[i+1].range
//                            let nextText = (original as NSString).substring(with: nextRange).lowercased()
//                            if isRelaxedMatch(spoken: currentSpoken, target: nextText) {
//                                isNextWord = true
//                            }
//                        }
//                        
//                        if isNextWord {
//                        } else {
//                            attributed.addAttribute(.foregroundColor, value: UIColor.systemRed, range: wordRange)
//                            spokenIndex += 1
//                        }
//                    }
//                }
//            }
//            
//            return attributed
//        }
//        private func normalizedWords(from text: String) -> [String] {
//            let clean = text
//                .lowercased()
//                .replacingOccurrences(of: "[^a-z\\s]", with: "", options: .regularExpression)
//
//            return clean
//                .components(separatedBy: .whitespaces)
//                .filter { !$0.isEmpty }
//        }
//    private func isRelaxedMatch(spoken: String, target: String) -> Bool {
//        let s = spoken.lowercased()
//        let t = target.lowercased()
//
//        if s == t { return true }
//
//        if s.hasPrefix(t) || t.hasPrefix(s) {
//            return true
//        }
//
//        let distance = levenshteinDistance(s, t)
//        let maxLen = max(s.count, t.count)
//        guard maxLen > 0 else { return false }
//
//        let similarity = 1.0 - Double(distance) / Double(maxLen)
//
//        switch maxLen {
//        case 1...3:
//            return similarity >= 0.7
//        case 4...6:
//            return similarity >= 0.65
//        default:
//            return similarity >= 0.6
//        }
//    }
//
//    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
//        let aChars = Array(a)
//        let bChars = Array(b)
//        let lenA = aChars.count
//        let lenB = bChars.count
//
//        if lenA == 0 { return lenB }
//        if lenB == 0 { return lenA }
//
//        var dp = Array(repeating: Array(repeating: 0, count: lenB + 1), count: lenA + 1)
//        for i in 0...lenA { dp[i][0] = i }
//        for j in 0...lenB { dp[0][j] = j }
//
//        for i in 1...lenA {
//            for j in 1...lenB {
//                if aChars[i - 1] == bChars[j - 1] {
//                    dp[i][j] = dp[i - 1][j - 1]
//                } else {
//                    dp[i][j] = min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + 1)
//                }
//            }
//        }
//        return dp[lenA][lenB]
//    }
}
extension UILabel {
    func addBottomBorder(color: UIColor, height: CGFloat = 1) {
        let border = CALayer()
        border.backgroundColor = color.cgColor
        border.frame = CGRect(
            x: 0,
            y: bounds.height - height,
            width: bounds.width,
            height: height
        )
        layer.addSublayer(border)
    }
}
