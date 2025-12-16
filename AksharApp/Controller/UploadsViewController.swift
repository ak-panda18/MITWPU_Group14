import UIKit
import VisionKit
import PhotosUI
import Vision

class UploadsViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!

    private var storedDocs: [StoredDoc] = []
    private var thumbnailsCache: [String: UIImage] = [:]
    private var filteredDocs: [StoredDoc] = []
    private var isSearching: Bool = false
    private var searchBar: UISearchBar?

    private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    private let indexFileName = "index.json"

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self

        configureCollectionLayout()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)


        loadIndexAndThumbnails()
        setupSearch()
    }

    private func configureCollectionLayout() {
        guard let flow = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        flow.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        flow.minimumInteritemSpacing = 16
        flow.minimumLineSpacing = 8
        flow.estimatedItemSize = .zero
    }

    
    @objc private func backgroundTapped() {
        hideSearchIfNeeded()
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    // MARK: - Persistence

    private static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func indexURL() -> URL {
        documentsURL.appendingPathComponent(indexFileName)
    }

    private func saveIndex() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(storedDocs)
            try data.write(to: indexURL(), options: .atomic)
        } catch {
            print("Failed saving index:", error)
        }
    }
    
    private func setupSearch() {
        let sb = UISearchBar()
        sb.placeholder = "Search documents"
        sb.delegate = self
        sb.translatesAutoresizingMaskIntoConstraints = false
        sb.isHidden = true

        view.addSubview(sb)

        NSLayoutConstraint.activate([
            sb.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            sb.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sb.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        searchBar = sb
    }
    
    private func hideSearchIfNeeded() {
        guard let searchBar, !searchBar.isHidden else { return }

        searchBar.resignFirstResponder()
        searchBar.text = ""
        searchBar.isHidden = true

        isSearching = false
        filteredDocs.removeAll()
        collectionView.reloadData()
    }

    private func loadIndexAndThumbnails() {
        DispatchQueue.global(qos: .userInitiated).async {
            let decoder = JSONDecoder()

            if let data = try? Data(contentsOf: self.indexURL()),
               let docs = try? decoder.decode([StoredDoc].self, from: data) {
                self.storedDocs = docs
            } else {
                self.storedDocs = []
            }

            var cache: [String: UIImage] = [:]
            for doc in self.storedDocs {
                let url = self.documentsURL.appendingPathComponent(doc.thumbnailFileName)
                if let data = try? Data(contentsOf: url),
                   let img = UIImage(data: data) {
                    cache[doc.id] = img
                }
            }

            DispatchQueue.main.async {
                self.thumbnailsCache = cache
                self.collectionView.reloadData()
            }
        }
    }


    // MARK: - Add Document

    private func presentAddOptions() {
        let alert = UIAlertController(title: "Add", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Scan with Camera", style: .default) { _ in
            self.presentDocumentScanner()
        })
        alert.addAction(UIAlertAction(title: "Choose from Photos", style: .default) { _ in
            self.presentPhotoPicker()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func presentDocumentScanner() {
        guard VNDocumentCameraViewController.isSupported else {
            showAlert(
                title: "Not supported",
                message: "Document scanner not supported on this device."
            )
            return
        }
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = self
        present(scanner, animated: true)
    }

    private func presentPhotoPicker() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 0
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - OCR & Document Processing

    private func processNewDocument(images: [UIImage]) {
        guard !images.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let ocrPages = self.recognizeTextPerPage(in: images)
            let id = UUID().uuidString
            let dateText = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
            let title = "Untitled"

            let fileName = self.saveDocumentImages(images, id: id)

            let thumbImage = self.makeThumbnail(from: images.first, maxSide: 140)
            let thumbName = "\(id)_thumb.png"
            let thumbURL = Self.documentsDirectory().appendingPathComponent(thumbName)
            if let timg = thumbImage, let tdata = timg.pngData() {
                try? tdata.write(to: thumbURL, options: .atomic)
            }

            let pagesFileName = "pages_\(id).json"
            let pagesURL = Self.documentsDirectory().appendingPathComponent(pagesFileName)
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(ocrPages)
                try data.write(to: pagesURL, options: .atomic)
            } catch {
                print("Failed writing pages JSON:", error)
            }
            
            let fullText = ocrPages
                .joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let ocrFileName = fullText.isEmpty ? nil : "\(id).txt"

            if let ocrFileName {
                try? fullText.data(using: .utf8)?
                    .write(to: self.documentsURL.appendingPathComponent(ocrFileName),
                           options: .atomic)
            }

            let doc = StoredDoc(id: id,
                                title: title,
                                dateText: dateText,
                                fileName: fileName,
                                thumbnailFileName: thumbName,
                                ocrTextFileName: ocrFileName,
                                pagesFileName: pagesFileName)

            DispatchQueue.main.async {
                self.promptForTitle(defaultTitle: title, excludingID: nil) { chosenTitle in
                    var finalDoc = doc
                    if let chosen = chosenTitle, !chosen.isEmpty {
                        finalDoc.title = chosen
                    }
                    self.storedDocs.insert(finalDoc, at: 0)
                    if let t = thumbImage { self.thumbnailsCache[finalDoc.id] = t }
                    self.saveIndex()
                    let insertIndexPath = IndexPath(item: 1, section: 0)
                    self.collectionView.insertItems(at: [insertIndexPath])
                    self.collectionView.scrollToItem(at: insertIndexPath, at: .centeredVertically, animated: true)
                }
            }
        }
    }
    
    // MARK: - Alert Helper

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    

    private func recognizeTextPerPage(in images: [UIImage]) -> [String] {
        var pagesResult: [String] = []

        for image in images {
            var pageText = ""
            guard let cg = image.cgImage else {
                pagesResult.append(pageText)
                continue
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do {
                try handler.perform([request])
                if let results = request.results {
                    for obs in results {
                        if let candidate = obs.topCandidates(1).first {
                            pageText += candidate.string + "\n"
                        }
                    }
                }
            } catch {
                print("OCR error on page:", error)
            }

            pagesResult.append(pageText.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return pagesResult
    }

    private func createPDF(from images: [UIImage], saveTo url: URL) throws {
        guard let first = images.first else { return }
        let pageRect = CGRect(origin: .zero, size: first.size)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        try renderer.writePDF(to: url, withActions: { ctx in
            for img in images {
                ctx.beginPage()
                img.draw(in: pageRect)
            }
        })
    }

    private func saveDocumentImages(_ images: [UIImage], id: String) -> String {
        if images.count > 1 {
            let name = "\(id).pdf"
            try? createPDF(from: images, saveTo: documentsURL.appendingPathComponent(name))
            return name
        } else {
            let name = "\(id).png"
            if let data = images.first?.jpegData(compressionQuality: 0.9) {
                try? data.write(to: documentsURL.appendingPathComponent(name))
            }
            return name
        }
    }

    
    private func makeThumbnail(from image: UIImage?, maxSide: CGFloat) -> UIImage? {
        guard let image = image else { return nil }
        let size = image.size
        let aspect = size.width / size.height
        var target: CGSize
        if aspect >= 1 {
            target = CGSize(width: maxSide, height: maxSide / aspect)
        } else {
            target = CGSize(width: maxSide * aspect, height: maxSide)
        }
        UIGraphicsBeginImageContextWithOptions(target, true, 0)
        image.draw(in: CGRect(origin: .zero, size: target))
        let thumb = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return thumb
    }

    // MARK: - Open Document

    private func openDocument(at index: Int , from docs : [StoredDoc]) {
        guard docs.indices.contains(index) else { return }
        let doc = docs[index]
        guard let pagesFile = doc.pagesFileName else {
            showAlert(
                title: "No page text",
                message: "This document has no extracted page text."
            )
            return
        }
        let pagesURL = Self.documentsDirectory().appendingPathComponent(pagesFile)
        guard let data = try? Data(contentsOf: pagesURL),
              let pages = try? JSONDecoder().decode([String].self, from: data),
              !pages.isEmpty else {
            showAlert(
                title: "Unable to load",
                message: "Could not read document pages."
            )
            return
        }

        guard let vc = storyboard?.instantiateViewController(withIdentifier: "LabelReadingVC") as? LabelReadingViewController else {
            print("LabelReadingVC not found in storyboard")
            return
        }
        vc.scannedPages = pages
        vc.scannedTitle = doc.title
        vc.currentIndex = 0
        vc.storyTextString = pages[0]
        
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Title prompt

    private func promptForTitle(defaultTitle: String, excludingID: String?, completion: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: "Document saved", message: "Give it a title (optional). Titles must be unique.", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Title"
            tf.text = defaultTitle
            tf.autocapitalizationType = .sentences
        }

        func isDuplicate(_ s: String) -> Bool {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return false }
            for doc in self.storedDocs {
                if let ex = excludingID, doc.id == ex { continue }
                if doc.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed.lowercased() {
                    return true
                }
            }
            return false
        }

        alert.addAction(UIAlertAction(title: "Skip", style: .cancel) { _ in completion(nil) })

        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            guard let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                completion(nil)
                return
            }
            if isDuplicate(text) {
                let warn = UIAlertController(title: "Duplicate title", message: "A document with this title already exists. Choose another title.", preferredStyle: .alert)
                warn.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    self.present(alert, animated: true, completion: nil)
                })
                self.present(warn, animated: true)
                return
            }
            completion(text)
        })
        present(alert, animated: true)
    }
    
    @IBAction func homeTapped(_ sender: UIButton) {
            navigationController?.popToRootViewController(animated: true)
        }

    @IBAction func searchTapped(_ sender: UIButton) {
        guard let searchBar else { return }

        searchBar.isHidden = false
        searchBar.becomeFirstResponder()
    }
    // MARK: - Helpers

    private func placeholderPlusImage() -> UIImage? {
        let size = CGSize(width: 140, height: 140)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.systemGray5.setFill()
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 20).fill()
        let plus = UIBezierPath()
        plus.lineWidth = 4
        UIColor.label.setStroke()
        let cx = size.width / 2
        let cy = size.height / 2
        plus.move(to: CGPoint(x: cx - 20, y: cy))
        plus.addLine(to: CGPoint(x: cx + 20, y: cy))
        plus.move(to: CGPoint(x: cx, y: cy - 20))
        plus.addLine(to: CGPoint(x: cx, y: cy + 20))
        plus.stroke()
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}

// MARK: - UICollectionViewDataSource

extension UploadsViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }
    
    private var currentDocs: [StoredDoc] {
        return isSearching ? filteredDocs : storedDocs
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return currentDocs.count + 1
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "UploadCell",
            for: indexPath
        ) as? UploadsCollectionViewCell else {
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
            cell.imageView.image = UIImage(named: "plus_tile") ?? placeholderPlusImage()
        } else {
            let doc = currentDocs[indexPath.item - 1]
            cell.titleLabel.text = doc.title
            cell.dateLabel.text = doc.dateText
            cell.titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            cell.containerView.backgroundColor = .systemBackground

            if let thumb = thumbnailsCache[doc.id] {
                cell.imageView.image = thumb
            } else {
                let url = Self.documentsDirectory().appendingPathComponent(doc.thumbnailFileName)
                if let data = try? Data(contentsOf: url),
                   let img = UIImage(data: data) {
                    thumbnailsCache[doc.id] = img
                    cell.imageView.image = img
                } else {
                    cell.imageView.image = UIImage(named: "doc_placeholder")
                }
            }
        }

        cell.titleLabel.textAlignment = .center
        cell.dateLabel.textAlignment = .center

        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout & Context Menu

extension UploadsViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {

        if indexPath.item == 0 {
            presentAddOptions()
        } else {
            openDocument(at: indexPath.item - 1 , from : currentDocs)
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width: CGFloat = collectionView.bounds.width / 2 - 25
        let height: CGFloat = 210
        return CGSize(width: width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        if indexPath.item == 0 { return nil }

        let docIndex = indexPath.item - 1
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in

            let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
                self.renameDocument(at: docIndex)
            }

            let duplicate = UIAction(title: "Duplicate", image: UIImage(systemName: "doc.on.doc")) { _ in
                self.duplicateDocument(at: docIndex)
            }

            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                let alert = UIAlertController(title: "Delete", message: "Are you sure you want to delete this document?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                    self.deleteDocument(at: docIndex)
                })
                self.present(alert, animated: true)
            }

            return UIMenu(title: "", children: [rename, duplicate, delete])
        }
    }
}

// MARK: - Rename / Duplicate / Delete

extension UploadsViewController {

    private func renameDocument(at index: Int) {
        guard storedDocs.indices.contains(index) else { return }
        let doc = storedDocs[index]
        let alert = UIAlertController(title: "Rename", message: "Enter new title", preferredStyle: .alert)
        alert.addTextField { tf in tf.text = doc.title }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            guard let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
            for (i, d) in self.storedDocs.enumerated() where i != index {
                if d.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == text.lowercased() {
                    let warn = UIAlertController(title: "Duplicate title", message: "A document with this title already exists.", preferredStyle: .alert)
                    warn.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(warn, animated: true)
                    return
                }
            }
            self.storedDocs[index].title = text
            self.saveIndex()
            self.collectionView.reloadItems(at: [IndexPath(item: index + 1, section: 0)])
        })
        present(alert, animated: true)
    }

    private func duplicateDocument(at index: Int) {
        guard storedDocs.indices.contains(index) else { return }
        var original = storedDocs[index]
        original.id = UUID().uuidString
        original.title += " Copy"

        let originalFileURL = Self.documentsDirectory().appendingPathComponent(original.fileName)
        let newFileName = original.id + (original.fileName.hasSuffix(".pdf") ? ".pdf" : ".png")
        let newFileURL = Self.documentsDirectory().appendingPathComponent(newFileName)
        try? FileManager.default.copyItem(at: originalFileURL, to: newFileURL)
        original.fileName = newFileName

        let thumbURL = Self.documentsDirectory().appendingPathComponent(original.thumbnailFileName)
        let newThumbName = "\(original.id)_thumb.png"
        let newThumbURL = Self.documentsDirectory().appendingPathComponent(newThumbName)
        try? FileManager.default.copyItem(at: thumbURL, to: newThumbURL)
        original.thumbnailFileName = newThumbName

        storedDocs.insert(original, at: 0)
        if let img = thumbnailsCache[storedDocs[index].id] {
            thumbnailsCache[original.id] = img
        }
        saveIndex()
        collectionView.insertItems(at: [IndexPath(item: 1, section: 0)])
    }

    private func deleteDocument(at index: Int) {
        guard storedDocs.indices.contains(index) else { return }
        let doc = storedDocs.remove(at: index)
        [doc.fileName, doc.thumbnailFileName, doc.pagesFileName, doc.ocrTextFileName].forEach {
            if let f = $0 {
                try? FileManager.default.removeItem(at: Self.documentsDirectory().appendingPathComponent(f))
            }
        }
        thumbnailsCache.removeValue(forKey: doc.id)
        saveIndex()
        collectionView.deleteItems(at: [IndexPath(item: index + 1, section: 0)])
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate

extension UploadsViewController: VNDocumentCameraViewControllerDelegate {

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true)
        var images: [UIImage] = []
        for i in 0..<scan.pageCount {
            images.append(scan.imageOfPage(at: i))
        }
        processNewDocument(images: images)
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true)
        print("Scanner error:", error)
    }
}

// MARK: - PHPickerViewControllerDelegate

extension UploadsViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        var images: [UIImage] = []
        let group = DispatchGroup()
        for result in results {
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                    if let img = obj as? UIImage {
                        images.append(img)
                    }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            self.processNewDocument(images: images)
        }
    }
}
extension UploadsViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard !searchText.isEmpty else {
            isSearching = false
            filteredDocs.removeAll()
            collectionView.reloadData()
            return
        }

        isSearching = true
        filteredDocs = storedDocs.filter {
            $0.title.lowercased().contains(searchText.lowercased())
        }

        collectionView.reloadData()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        hideSearchIfNeeded()
    }

}
