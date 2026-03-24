import UIKit

class CheckpointCell: UICollectionViewCell {
    
    // MARK: - Outlets
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var accuracyLabel: UILabel!
    @IBOutlet weak var chevronButton: UIButton!
    
    // MARK: - UI Layers
    private let bottomBorder = CALayer()
    
    // MARK: - Callbacks
    var didTapChevron: (() -> Void)?
    
    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        self.layer.cornerRadius = 8
        bottomBorder.backgroundColor = UIColor.systemGray4.cgColor
        self.layer.addSublayer(bottomBorder)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        bottomBorder.frame = CGRect(x: 0, y: self.bounds.height - 1, width: self.bounds.width, height: 1)
    }
    
    // MARK: - Actions
    @IBAction func chevronTapped(_ sender: UIButton) {
        didTapChevron?()
    }
    
    // MARK: - Actions
    func configure(with stats: DailyStats) {
        dateLabel.text = stats.formattedDate
        accuracyLabel.text = "\(stats.accuracy)%"
        let color: UIColor = stats.accuracy >= 80 ? .systemGreen : (stats.accuracy >= 40 ? .systemOrange : .systemRed)
        accuracyLabel.textColor = color
    }
}
