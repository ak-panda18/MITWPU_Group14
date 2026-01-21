import UIKit

class CheckpointHistoryCell: UICollectionViewCell {
    
    // MARK: - Outlets
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var accuracyLabel: UILabel!
    
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
    func configure(date: String, accuracy: Int) {
        dateLabel.text = date
        accuracyLabel.text = "\(accuracy)%"
        
        if accuracy >= 80 {
            accuracyLabel.textColor = .systemGreen
        } else if accuracy >= 40 {
            accuracyLabel.textColor = .systemOrange
        } else {
            accuracyLabel.textColor = .systemRed
        }
    }
}
