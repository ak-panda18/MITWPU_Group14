import UIKit
import VisionKit
import PhotosUI

class UploadsViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    
    private var isSearching: Bool = false
    private var filteredDocs: [StoredDoc] = []
    private var searchBar: UISearchBar?
    
    private lazy var fallbackPlusImage: UIImage? = placeholderPlusImage()
    
    private var currentDocs: [StoredDoc] {
        if isSearching {
            return filteredDocs
        }
        return OCRManager.shared.getAllDocuments()
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        configureCollectionLayout()
        setupSearch()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(hideSearchIfNeeded))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        collectionView.reloadData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    // MARK: - Layout Configuration (Restored)
    private func configureCollectionLayout() {
        guard let flow = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        flow.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        flow.minimumInteritemSpacing = 16
        flow.minimumLineSpacing = 8
        flow.estimatedItemSize = .zero
    }

    // MARK: - Actions
    @IBAction func homeTapped(_ sender: UIButton) {
        navigationController?.popToRootViewController(animated: true)
    }

    @IBAction func searchTapped(_ sender: UIButton) {
        searchBar?.isHidden = false
        searchBar?.becomeFirstResponder()
    }
    
    // MARK: - Add Document Logic
    private func presentAddOptions() {
        let alert = UIAlertController(title: "Add Document", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Scan with Camera", style: .default) { _ in self.presentScanner() })
        alert.addAction(UIAlertAction(title: "Choose from Photos", style: .default) { _ in self.presentPhotoPicker() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Handlers
    private func handleNewImages(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        
        OCRManager.shared.processNewDocument(images: images) { [weak self] newDoc in
            self?.collectionView.reloadData()
            self?.promptForTitle(doc: newDoc)
        }
    }
    
    private func promptForTitle(doc: StoredDoc) {
        let alert = UIAlertController(title: "Document Saved", message: "Give it a title", preferredStyle: .alert)
        alert.addTextField { $0.text = doc.title }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let text = alert.textFields?.first?.text, !text.isEmpty {
                OCRManager.shared.renameDocument(docId: doc.id, newTitle: text)
                self.collectionView.reloadData()
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func openDocument(at index: Int) {
        let doc = currentDocs[index]
        
        if let pages = OCRManager.shared.getPages(for: doc), !pages.isEmpty {
            if let vc = storyboard?.instantiateViewController(withIdentifier: "LabelReadingVC") as? LabelReadingViewController {
                vc.scannedPages = pages
                vc.scannedTitle = doc.title
                vc.currentIndex = 0
                vc.storyTextString = pages[0]
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

}

// MARK: - Collection View DataSource
extension UploadsViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return currentDocs.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UploadCell", for: indexPath) as? UploadsCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        cell.containerView.layer.borderWidth = 1
        cell.containerView.layer.borderColor = UIColor.systemGray4.cgColor
        cell.containerView.layer.cornerRadius = 16
        cell.containerView.clipsToBounds = true
        
        if indexPath.item == 0 {
            cell.titleLabel.text = "New File"
            cell.dateLabel.text = ""
            cell.titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
            cell.containerView.backgroundColor = .systemGray5
            cell.imageView.image = UIImage(named: "plus_tile") ?? fallbackPlusImage
        } else {
            let doc = currentDocs[indexPath.item - 1]
            cell.titleLabel.text = doc.title
            cell.dateLabel.text = doc.dateText
            cell.titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            cell.containerView.backgroundColor = .systemBackground
            
            if let thumb = OCRManager.shared.getThumbnail(for: doc) {
                cell.imageView.image = thumb
            } else {
                cell.imageView.image = UIImage(systemName: "doc.text")
            }
        }
        
        cell.titleLabel.textAlignment = .center
        cell.dateLabel.textAlignment = .center
        
        return cell
    }
}

// MARK: - Collection View Delegate & Layout
extension UploadsViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == 0 {
            presentAddOptions()
        } else {
            openDocument(at: indexPath.item - 1)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width: CGFloat = collectionView.bounds.width / 2 - 25
        let height: CGFloat = 210
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.item > 0 else { return nil }
        let index = indexPath.item - 1
        let doc = currentDocs[index]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                OCRManager.shared.deleteDocument(docId: doc.id)
                self.collectionView.reloadData()
            }
            let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
                self.promptForTitle(doc: doc)
            }
            let duplicate = UIAction(title: "Duplicate", image: UIImage(systemName: "doc.on.doc")) { _ in
                OCRManager.shared.duplicateDocument(docId: doc.id)
                self.collectionView.reloadData()
            }
            return UIMenu(children: [rename, duplicate, delete])
        }
    }
}

// MARK: - Gesture Delegate
extension UploadsViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let touchView = touch.view, touchView.isDescendant(of: collectionView) {
            return false
        }
        return true
    }
}

// MARK: - Helpers & Extensions
extension UploadsViewController: UISearchBarDelegate, VNDocumentCameraViewControllerDelegate, PHPickerViewControllerDelegate {
    
    private func placeholderPlusImage() -> UIImage? {
        let size = CGSize(width: 140, height: 140)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemGray5.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 20).fill()
            
            let plusPath = UIBezierPath()
            plusPath.lineWidth = 4
            let center = CGPoint(x: size.width/2, y: size.height/2)
            
            plusPath.move(to: CGPoint(x: center.x - 20, y: center.y))
            plusPath.addLine(to: CGPoint(x: center.x + 20, y: center.y))
            
            plusPath.move(to: CGPoint(x: center.x, y: center.y - 20))
            plusPath.addLine(to: CGPoint(x: center.x, y: center.y + 20))
            
            UIColor.systemGray.setStroke()
            plusPath.stroke()
        }
    }
    
    private func setupSearch() {
        let sb = UISearchBar()
        sb.placeholder = "Search documents"
        sb.delegate = self
        sb.isHidden = true
        sb.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sb)
        
        NSLayoutConstraint.activate([
            sb.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            sb.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sb.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        searchBar = sb
    }
    
    @objc private func hideSearchIfNeeded() {
        searchBar?.resignFirstResponder()
        searchBar?.isHidden = true
        isSearching = false
        collectionView.reloadData()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
        } else {
            isSearching = true
            filteredDocs = OCRManager.shared.getAllDocuments().filter {
                $0.title.lowercased().contains(searchText.lowercased())
            }
        }
        collectionView.reloadData()
    }
    
    func presentScanner() {
        guard VNDocumentCameraViewController.isSupported else { return }
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = self
        present(scanner, animated: true)
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        var images: [UIImage] = []
        for i in 0..<scan.pageCount { images.append(scan.imageOfPage(at: i)) }
        controller.dismiss(animated: true)
        handleNewImages(images)
    }
    
    func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        let group = DispatchGroup()
        
        var images: [UIImage?] = Array(repeating: nil, count: results.count)
        
        for (index, result) in results.enumerated() {
            group.enter()
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                    if let img = image as? UIImage {
                        DispatchQueue.main.async {
                            images[index] = img
                        }
                    }
                    group.leave()
                }
            } else {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let validImages = images.compactMap { $0 }
            self.handleNewImages(validImages)
        }
    }

}
