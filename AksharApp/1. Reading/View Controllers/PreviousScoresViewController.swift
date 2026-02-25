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
