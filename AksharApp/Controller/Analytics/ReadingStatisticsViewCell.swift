import UIKit

class ReadingStatisticsViewCell: UICollectionViewCell,
                                 UICollectionViewDelegate,
                                 UICollectionViewDataSource,
                                 UICollectionViewDelegateFlowLayout {
    
    // MARK: - Outlets
    @IBOutlet weak var readingHoursLabel: UILabel!
    @IBOutlet weak var currentLevelLabel: UILabel!
    @IBOutlet weak var levelDescriptionLabel: UILabel!
    @IBOutlet weak var checkpointCollectionView: UICollectionView!
    @IBOutlet weak var seeAllButton: UIButton?
    @IBOutlet weak var leftParentView: UIView!
    @IBOutlet weak var rightParentView: UIView!

    // MARK: - Properties
    private var dailyStatsData: [DailyStats] = []
    private var isWeeklyMode: Bool = true
    private let bottomBorder = CALayer()
    var onCheckpointSelected: ((DailyStats) -> Void)?
    
    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        self.contentView.preservesSuperviewLayoutMargins = false
        self.contentView.layoutMargins = .zero
        
        setupCheckpointCollectionView()
        
        bottomBorder.backgroundColor = UIColor.systemGray4.cgColor
        self.layer.addSublayer(bottomBorder)
        readingHoursLabel.layer.cornerRadius = 50
        readingHoursLabel.layer.borderColor = UIColor.systemGray4.cgColor
        readingHoursLabel.layer.shadowColor = UIColor.black.cgColor
        readingHoursLabel.layer.shadowOpacity = 0.2
        readingHoursLabel.layer.shadowOffset = CGSize(width: 0, height: 5)
        readingHoursLabel.layer.borderWidth = 1
        seeAllButton?.isHidden = true
        seeAllButton?.isEnabled = false
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        bottomBorder.frame = CGRect(x: 0, y: self.bounds.height - 1, width: self.bounds.width, height: 1)
        checkpointCollectionView.collectionViewLayout.invalidateLayout()
    }

    // MARK: - Setup
    private func setupCheckpointCollectionView() {
        checkpointCollectionView.delegate = self
        checkpointCollectionView.dataSource = self
        checkpointCollectionView.alwaysBounceVertical = true
        leftParentView.layer.borderWidth = 1
        leftParentView.layer.borderColor = UIColor.systemGray4.cgColor
        rightParentView.layer.borderWidth = 1
        rightParentView.layer.borderColor = UIColor.systemGray4.cgColor
        if let layout = checkpointCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
        }
    }
    
    // MARK: - View Mode
    func updateViewMode(isWeekly: Bool) {
        self.isWeeklyMode = isWeekly
        seeAllButton?.isHidden = true
    }

    // MARK: - Actions
    @IBAction func seeAllButtonTapped(_ sender: UIButton) {
    }

    // MARK: - Configuration
    func configure(readingTime: NSAttributedString, level: String, levelDescription: String, stats: [DailyStats]) {
            readingHoursLabel.attributedText = readingTime

            currentLevelLabel.text = level
        currentLevelLabel.layer.borderWidth = 1
        currentLevelLabel.layer.borderColor = UIColor.systemGray4.cgColor
        currentLevelLabel.layer.cornerRadius = 10
        
            levelDescriptionLabel.text = levelDescription
            
            self.dailyStatsData = stats
            self.layoutIfNeeded()
            checkpointCollectionView.reloadData()
        }

    // MARK: - CollectionView DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dailyStatsData.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CheckpointCell", for: indexPath) as! CheckpointCell
        
        let stats = dailyStatsData[indexPath.item]
        cell.configure(with: stats)

        cell.chevronButton.isHidden = !isWeeklyMode
        cell.didTapChevron = { [weak self] in
            if self?.isWeeklyMode == true { self?.onCheckpointSelected?(stats) }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isWeeklyMode {
            onCheckpointSelected?(dailyStatsData[indexPath.item])
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        return UIEdgeInsets(
            top: 8,
            left: 20,
            bottom: 8,
            right: 20
        )
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {

        let insets = self.collectionView(
            collectionView,
            layout: collectionViewLayout,
            insetForSectionAt: 0
        )

        let width = collectionView.bounds.width
            - insets.left
            - insets.right

        return CGSize(width: width, height: 80)
    }
}
