import UIKit

class CheckpointDetailsViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    // MARK: - Outlets
    @IBOutlet weak var collectionView: UICollectionView!
    
    // MARK: - Properties
    var historyData: [CheckpointAttempt] = []
    var stats: DailyStats?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        loadData()
    }
    
    // MARK: - Setup
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
    }
    
    // MARK: - Data Loading
    private func loadData() {
        self.historyData = CheckpointHistoryManager.shared.getAllAttempts()
        collectionView.reloadData()
    }

    // MARK: - CollectionView DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return historyData.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CheckpointDetailCell", for: indexPath) as! CheckpointDetailCell
        
        let attempt = historyData[indexPath.item]
        cell.configure(with: attempt)
        
        return cell
    }

    // MARK: - Header Configuration
    func collectionView(_ collectionView: UICollectionView,
                            viewForSupplementaryElementOfKind kind: String,
                            at indexPath: IndexPath) -> UICollectionReusableView {
            
            if kind == UICollectionView.elementKindSectionHeader {
                let header = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: "Header",
                    for: indexPath
                )
            
                header.layer.borderWidth = 1.0
                header.layer.borderColor = UIColor.systemBrown.cgColor
                header.backgroundColor = .systemBackground
                
                header.layer.cornerRadius = 12
                header.layer.masksToBounds = true
                
                return header
            }
            return UICollectionReusableView()
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
        return CGSize(width: collectionView.bounds.width - 10, height: 60)
    }
}
