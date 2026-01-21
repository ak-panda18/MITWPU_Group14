import UIKit

class WritingAccuracyViewCell: UICollectionViewCell {

    // MARK: - Outlets
    @IBOutlet weak var lettersCardView: UIView!
    @IBOutlet weak var wordsCardView: UIView!
    @IBOutlet weak var numbersCardView: UIView!

    @IBOutlet weak var lettersPercentageLabel: UILabel!
    @IBOutlet weak var wordsPercentageLabel: UILabel!
    @IBOutlet weak var numbersPercentageLabel: UILabel!
    
    @IBOutlet weak var lettersComparisonLabel: UILabel!
    @IBOutlet weak var wordsComparisonLabel: UILabel!
    @IBOutlet weak var numbersComparisonLabel: UILabel!
    
    @IBOutlet weak var lettersStackView: UIStackView!
    @IBOutlet weak var lettersTitleLabel: UILabel!
    @IBOutlet weak var wordsStackView: UIStackView!
    @IBOutlet weak var wordsTitleLabel: UILabel!
    @IBOutlet weak var numbersStackView: UIStackView!
    @IBOutlet weak var numbersTitleLabel: UILabel!
    
    @IBOutlet weak var WritingAccuracyView: UIView!
    
    // MARK: - Callbacks
    var onLettersTapped: (() -> Void)?
    var onWordsTapped: (() -> Void)?
    var onNumbersTapped: (() -> Void)?
    
    // MARK: - Actions
    @IBAction func lettersTapped(_ sender: UIButton) {
        onLettersTapped?()
    }

    @IBAction func wordsTapped(_ sender: UIButton) {
        onWordsTapped?()
    }

    @IBAction func numbersTapped(_ sender: UIButton) {
        onNumbersTapped?()
    }

    // MARK: - Border Layer
    private let bottomBorder = CALayer()

    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCard(lettersCardView)
        setupCard(wordsCardView)
        setupCard(numbersCardView)
        bottomBorder.backgroundColor = UIColor.systemGray4.cgColor
        self.layer.addSublayer(bottomBorder)
        
        if let stack = lettersStackView {
        stack.setCustomSpacing(10, after: lettersTitleLabel)
        stack.setCustomSpacing(50, after: lettersCardView)
        }
        if let stack = wordsStackView {
        stack.setCustomSpacing(10, after: wordsTitleLabel)
        stack.setCustomSpacing(50, after: wordsCardView)
        }
        if let stack = numbersStackView {
        stack.setCustomSpacing(10, after: numbersTitleLabel)
        stack.setCustomSpacing(50, after: numbersCardView)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        bottomBorder.frame = CGRect(x: 0, y: self.bounds.height - 1, width: self.bounds.width, height: 1)
    }
    
    // MARK: - Setup
    private func setupCard(_ view: UIView) {
        view.layer.cornerRadius = 40
        view.layer.borderWidth = 2.0
        view.backgroundColor = .systemBackground
        
    }

    // MARK: - Configuration
        func configure(
            letters: String, lettersDelta: String, lettersColor: UIColor, lettersComparisonText: String,
            words: String, wordsDelta: String, wordsColor: UIColor, wordsComparisonText: String,
            numbers: String, numbersDelta: String, numbersColor: UIColor, numbersComparisonText: String
        ) {
            lettersPercentageLabel.text = letters
            wordsPercentageLabel.text = words
            numbersPercentageLabel.text = numbers
            func setAttributedText(label: UILabel, delta: String, color: UIColor, suffix: String) {
                let fullString = "\(delta) \(suffix)"
                let attributed = NSMutableAttributedString(string: fullString)
                let deltaRange = (fullString as NSString).range(of: delta)
                attributed.addAttribute(.foregroundColor, value: color, range: deltaRange)
                
                let suffixRange = (fullString as NSString).range(of: suffix)
                attributed.addAttribute(.foregroundColor, value: UIColor.black, range: suffixRange)
                
                label.attributedText = attributed
            }
            setAttributedText(label: lettersComparisonLabel, delta: lettersDelta, color: lettersColor, suffix: lettersComparisonText)
            setAttributedText(label: wordsComparisonLabel, delta: wordsDelta, color: wordsColor, suffix: wordsComparisonText)
            setAttributedText(label: numbersComparisonLabel, delta: numbersDelta, color: numbersColor, suffix: numbersComparisonText)
        }
    
        func setColors(letters: UIColor, words: UIColor, numbers: UIColor) {
            lettersPercentageLabel.textColor = letters
            lettersCardView.layer.borderColor = letters.cgColor
            lettersCardView.layer.borderWidth = 3
            
            wordsPercentageLabel.textColor = words
            wordsCardView.layer.borderColor = words.cgColor
            wordsCardView.layer.borderWidth = 3
            
            numbersPercentageLabel.textColor = numbers
            numbersCardView.layer.borderColor = numbers.cgColor
            numbersCardView.layer.borderWidth = 3
        }
    func setComparisonColors(letters: UIColor, words: UIColor, numbers: UIColor) {
            lettersComparisonLabel.textColor = letters
            wordsComparisonLabel.textColor = words
            numbersComparisonLabel.textColor = numbers
        }
}
