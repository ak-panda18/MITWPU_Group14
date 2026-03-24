import UIKit

class CheckpointHistoryViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!
    
    var historyData: [CheckpointAttempt] = []

    // MARK: - Injected
    var checkpointHistoryManager: CheckpointHistoryManager!

    private func verifyDependencies() {
        assert(checkpointHistoryManager != nil, "checkpointHistoryManager was not injected into \(type(of: self))")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        verifyDependencies()
        setupCollectionView()
        let historyNib = UINib(nibName: "CheckpointHistoryCell", bundle: nil)
        collectionView.register(historyNib, forCellWithReuseIdentifier: "HistoryCell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }
    
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
    }
    
    private func loadData() {
        historyData = checkpointHistoryManager.getAllAttempts()
        collectionView.reloadData()
    }

    // MARK: - CollectionView DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return historyData.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HistoryCell", for: indexPath) as? CheckpointHistoryCell else { return UICollectionViewCell() }
        
        let data = historyData[indexPath.item]
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: data.timestamp)
        
        cell.configure(date: dateString, accuracy: data.accuracy)
        
        return cell
    }
    
    // MARK: - Header Configuration
    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: "Header",
            for: indexPath
        )
        
        header.layer.borderWidth = 1.0
        header.layer.borderColor = UIColor.systemGray4.cgColor
        header.backgroundColor = .systemBackground
        header.layer.cornerRadius = 12
        header.layer.masksToBounds = true
        
        if let titleLabel = header.viewWithTag(100) as? UILabel {
            titleLabel.font = UIFont.systemFont(ofSize: titleLabel.font.pointSize, weight: .semibold)
        }
        
        return header
    }

    // MARK: - Layout Delegate
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 50)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 80)
    }

}
