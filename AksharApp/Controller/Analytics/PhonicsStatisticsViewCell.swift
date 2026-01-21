import UIKit

class PhonicsStatisticsViewCell: UICollectionViewCell {

    // MARK: - Outlets
    @IBOutlet weak var soundDetectivePercentageLabel: UILabel!
    @IBOutlet weak var quizMyStoryPercentageLabel: UILabel!
    @IBOutlet weak var rhymeSoundsPercentageLabel: UILabel!
    @IBOutlet weak var wordBuilderPercentageLabel: UILabel!
    @IBOutlet weak var fluencyDrillsPercentageLabel: UILabel!
    @IBOutlet weak var soundDetectiveView: UIView!
    @IBOutlet weak var quizMyStoryView: UIView!
    @IBOutlet weak var rhymeSoundsView: UIView!
    @IBOutlet weak var wordBuilderView: UIView!
    @IBOutlet weak var fluencyDrillsView: UIView!
    @IBOutlet weak var PhonicsStatisticsView: UIView!
    
    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCard(soundDetectiveView)
        setupCard(quizMyStoryView)
        setupCard(rhymeSoundsView)
        setupCard(wordBuilderView)
        setupCard(fluencyDrillsView)
    }
    
    // MARK: - Setup
    private func setupCard(_ view: UIView?) {
        view?.layer.cornerRadius = 30
        view?.layer.borderWidth = 2.0
        view?.backgroundColor = .systemBackground
    }

    // MARK: - Configuration
    func configure(sound: String, quiz: String, rhyme: String, word: String, fluency: String) {

        soundDetectivePercentageLabel.text = sound
        updateCardStyle(
            view: soundDetectiveView,
            label: soundDetectivePercentageLabel,
            score: extractScore(from: sound)
        )

        quizMyStoryPercentageLabel.text = quiz
        updateCardStyle(
            view: quizMyStoryView,
            label: quizMyStoryPercentageLabel,
            score: extractScore(from: quiz)
        )

        rhymeSoundsPercentageLabel.text = rhyme
        updateCardStyle(
            view: rhymeSoundsView,
            label: rhymeSoundsPercentageLabel,
            score: extractScore(from: rhyme)
        )

        wordBuilderPercentageLabel.text = word
        updateCardStyle(
            view: wordBuilderView,
            label: wordBuilderPercentageLabel,
            score: extractScore(from: word)
        )

        fluencyDrillsPercentageLabel.text = fluency
        updateCardStyle(
            view: fluencyDrillsView,
            label: fluencyDrillsPercentageLabel,
            score: extractScore(from: fluency),
            greenThreshold: 16,
            orangeThreshold: 8
        )
    }
    
    // MARK: - Styling Helpers
    private func updateCardStyle(
        view: UIView?,
        label: UILabel,
        score: Int?,
        greenThreshold: Int = 80,
        orangeThreshold: Int = 40
    ) {

        guard let score = score else {
            label.textColor = .systemGray
            view?.layer.borderColor = UIColor.systemGray4.cgColor
            return
        }

        let color: UIColor =
            score >= greenThreshold ? .systemGreen :
            score >= orangeThreshold ? .systemOrange :
                                       .systemRed
        label.textColor = color
        view?.layer.borderColor = color.cgColor
    }
    
    // MARK: - Data Parsing
    private func extractScore(from text: String) -> Int? {
        let digits = text.filter { $0.isNumber }
        return Int(digits)
    }
}
