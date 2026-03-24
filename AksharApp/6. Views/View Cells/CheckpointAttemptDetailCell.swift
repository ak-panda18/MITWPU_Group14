import UIKit

class CheckpointDetailCell: UICollectionViewCell {
    
    // MARK: - Outlets
    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var middleLabel: UILabel!
    @IBOutlet weak var rightLabel: UILabel!
    
    // MARK: - UI Layers
    private let bottomBorder = CALayer()
    
    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        bottomBorder.backgroundColor = UIColor.systemGray4.cgColor
        self.layer.addSublayer(bottomBorder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let height: CGFloat = 1.0
        bottomBorder.frame = CGRect(
            x: 0,
            y: self.bounds.height - height,
            width: self.bounds.width,
            height: height
        )
    }
    
    // MARK: - Configuration
    func configure(with attempt: CheckpointAttempt) {
            leftLabel.text = attempt.storyTitle
            middleLabel.text = "Checkpoint: \(attempt.checkpointNumber)"
            
            let accuracy = attempt.accuracy
            rightLabel.text = "\(accuracy)%"
            if accuracy >= 80 {
                rightLabel.textColor = .systemGreen
            } else if accuracy >= 40 {
                rightLabel.textColor = .systemOrange
            } else {
                rightLabel.textColor = .systemRed
            }
            rightLabel.layer.borderWidth = 1.5
            rightLabel.layer.borderColor = rightLabel.textColor.cgColor
            rightLabel.layer.cornerRadius = 15
        }}
