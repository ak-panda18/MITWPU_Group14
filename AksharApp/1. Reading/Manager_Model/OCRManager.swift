import UIKit
import Vision
import PDFKit

class OCRManager {
    static let shared = OCRManager()
    
    // MARK: - Properties
    private(set) var documents: [StoredDoc] = []
    private var thumbnailsCache: [String: UIImage] = [:]
    
    private let fileManager = FileManager.default
    private let indexFileName = "index.json"
    
    private var documentsURL: URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private init() {
        loadIndex()
    }
    
    // MARK: - Data Access
    func getAllDocuments() -> [StoredDoc] {
        return documents
    }
    
    func getThumbnail(for doc: StoredDoc) -> UIImage? {
        if let cached = thumbnailsCache[doc.id] { return cached }
        
        let url = documentsURL.appendingPathComponent(doc.thumbnailFileName)
        if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
            thumbnailsCache[doc.id] = img
            return img
        }
        return nil
    }
    
    // MARK: - Core Action: Process New Scan
    func processNewDocument(images: [UIImage], completion: @escaping (StoredDoc) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Perform OCR (Improved Logic)
            let ocrPages = self.recognizeTextPerPage(in: images)
            
            // 2. Prepare Metadata
            let id = UUID().uuidString
//            let dateText = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
            let title = "Untitled"
            
            // 3. Save Files
            let fileName = self.saveDocumentImages(images, id: id)
            let thumbName = self.saveThumbnail(from: images.first, id: id)
            let pagesName = self.savePagesJSON(ocrPages, id: id)
            let textName = self.saveFullText(ocrPages, id: id)
            
            // 4. Create Document Object
            let newDoc = StoredDoc(
                            id: id,
                            title: title,
                            createdDate: Date(), // <--- CHANGE THIS: Pass raw Date() object
                            fileName: fileName,
                            thumbnailFileName: thumbName,
                            ocrTextFileName: textName,
                            pagesFileName: pagesName
                        )
            
            // 5. Update Local Index & Cache
            DispatchQueue.main.async {
                self.documents.insert(newDoc, at: 0)
                if let firstImg = images.first {
                    self.thumbnailsCache[id] = self.makeThumbnail(from: firstImg, maxSide: 140)
                }
                self.saveIndex()
                completion(newDoc)
            }
        }
    }
    
    // MARK: - Document Actions
    func renameDocument(docId: String, newTitle: String) {
        if let index = documents.firstIndex(where: { $0.id == docId }) {
            documents[index].title = newTitle
            saveIndex()
        }
    }
    
    func deleteDocument(docId: String) {
        guard let index = documents.firstIndex(where: { $0.id == docId }) else { return }
        let doc = documents.remove(at: index)
        thumbnailsCache.removeValue(forKey: doc.id)
        
        [doc.fileName, doc.thumbnailFileName, doc.pagesFileName, doc.ocrTextFileName].compactMap { $0 }.forEach { name in
            try? fileManager.removeItem(at: documentsURL.appendingPathComponent(name))
        }
        saveIndex()
    }
    
    func duplicateDocument(docId: String) {
        guard let index = documents.firstIndex(where: { $0.id == docId }) else { return }
        var original = documents[index]
        let newId = UUID().uuidString
        
        original.id = newId
        original.title += " Copy"
        
        let originalExt = original.fileName.hasSuffix(".pdf") ? ".pdf" : ".png"
        let newFileName = newId + originalExt
        try? fileManager.copyItem(at: documentsURL.appendingPathComponent(original.fileName),
                                  to: documentsURL.appendingPathComponent(newFileName))
        original.fileName = newFileName
        
        let newThumbName = "\(newId)_thumb.png"
        try? fileManager.copyItem(at: documentsURL.appendingPathComponent(original.thumbnailFileName),
                                  to: documentsURL.appendingPathComponent(newThumbName))
        original.thumbnailFileName = newThumbName
        
        if let pagesFile = original.pagesFileName {
            let newPagesName = "pages_\(newId).json"
            try? fileManager.copyItem(at: documentsURL.appendingPathComponent(pagesFile),
                                      to: documentsURL.appendingPathComponent(newPagesName))
            original.pagesFileName = newPagesName
        }
        
        if let textFile = original.ocrTextFileName {
            let newTextName = "\(newId).txt"
            try? fileManager.copyItem(at: documentsURL.appendingPathComponent(textFile),
                                      to: documentsURL.appendingPathComponent(newTextName))
            original.ocrTextFileName = newTextName
        }
        
        documents.insert(original, at: 0)
        if let cachedImg = thumbnailsCache[docId] {
            thumbnailsCache[newId] = cachedImg
        }
        saveIndex()
    }
    
    // MARK: - Internal Helpers
    
    private func saveIndex() {
        if let data = try? JSONEncoder().encode(documents) {
            try? data.write(to: documentsURL.appendingPathComponent(indexFileName))
        }
    }
    
    private func loadIndex() {
        let url = documentsURL.appendingPathComponent(indexFileName)
        guard let data = try? Data(contentsOf: url),
              let docs = try? JSONDecoder().decode([StoredDoc].self, from: data) else { return }
        self.documents = docs
        for doc in docs {
            let thumbUrl = documentsURL.appendingPathComponent(doc.thumbnailFileName)
            if let data = try? Data(contentsOf: thumbUrl), let img = UIImage(data: data) {
                thumbnailsCache[doc.id] = img
            }
        }
    }
    
    // MARK: - Improved OCR Logic (Fixes Centering & Hyphens)
    private func recognizeTextPerPage(in images: [UIImage]) -> [String] {
        var pagesResult: [String] = []

        for image in images {
            guard let cg = image.cgImage else {
                pagesResult.append("")
                continue
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-AU"]

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            
            do {
                try handler.perform([request])
                
                guard let observations = request.results, !observations.isEmpty else {
                    pagesResult.append("")
                    continue
                }
                
                // 1. Calculate Page Geometry to detect centering
                let xMins = observations.map { $0.boundingBox.minX }.sorted()
                let xMaxs = observations.map { $0.boundingBox.maxX }.sorted()
                
                let medianMinX = xMins[xMins.count / 2]
                let medianMaxX = xMaxs[xMaxs.count / 2]
                let pageWidth = medianMaxX - medianMinX
                let textBlockCenter = medianMinX + (pageWidth / 2.0)
                
                var fullPageText = ""
                var previousObs: VNRecognizedTextObservation?
                
                // 2. Iterate line by line
                for obs in observations {
                    guard let candidate = obs.topCandidates(1).first else { continue }
                    var text = candidate.string
                    
                    let lineMidX = obs.boundingBox.midX
                    let lineWidth = obs.boundingBox.width
                    
                    // Logic: If line is short and roughly in the middle, it's a Title
                    let isShortLine = lineWidth < (pageWidth * 0.85)
                    let isAlignedToCenter = abs(lineMidX - textBlockCenter) < (pageWidth * 0.15)
                    let isCentered = isShortLine && isAlignedToCenter
                    
                    if isCentered {
                        text = "<CENTER>" + text
                    }
                    
                    if let prev = previousObs {
                        let prevBottom = prev.boundingBox.minY
                        let currTop = obs.boundingBox.maxY
                        let verticalGap = prevBottom - currTop
                        let lineHeight = prev.boundingBox.height
                        
                        // Detect Paragraphs
                        let isPrevShort = (prev.boundingBox.maxX < (medianMaxX - (pageWidth * 0.15)))
                        let isBigGap = verticalGap > (lineHeight * 1.3)
                        let isIndented = !isCentered && (obs.boundingBox.minX > (medianMinX + (pageWidth * 0.05)))
                        
                        // HYPHENATION CHECK (Fixes "eter- \n nity")
                        var isHyphenated = false
                        if let lastCharIndex = fullPageText.lastIndex(where: { !$0.isWhitespace }),
                           fullPageText[lastCharIndex] == "-" {
                            isHyphenated = true
                            // Remove the hyphen to merge "eter-" and "nity" into "eternity"
                            fullPageText = String(fullPageText[..<lastCharIndex])
                        }
                        
                        // --- Merge Logic ---
                        if isHyphenated {
                            // Merge directly (no space, no newline) -> "eternity"
                            fullPageText += text
                        }
                        else if isCentered {
                            // Centered titles always get their own newlines
                            fullPageText += "\n\n" + text
                        }
                        else if isBigGap || (isPrevShort && !isHyphenated) || isIndented {
                            // Start new paragraph
                            fullPageText += "\n\n" + text
                        }
                        else {
                            // Standard line continuation: Merge with a space
                            fullPageText += " " + text
                        }
                    } else {
                        // First line of page
                        if isCentered && !text.contains("<CENTER>") {
                            text = "<CENTER>" + text
                        }
                        fullPageText = text
                    }
                    
                    previousObs = obs
                }
                
                pagesResult.append(fullPageText.trimmingCharacters(in: .whitespacesAndNewlines))
                
            } catch {
                print("OCR error on page:", error)
                pagesResult.append("")
            }
        }

        return pagesResult
    }
    
    // MARK: - Saving Helpers
    
    private func saveDocumentImages(_ images: [UIImage], id: String) -> String {
        if images.count > 1 {
            let name = "\(id).pdf"
            // Use Restored logic using original image size
            if let first = images.first {
                let pageRect = CGRect(origin: .zero, size: first.size)
                let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
                let data = renderer.pdfData { ctx in
                    for img in images {
                        ctx.beginPage()
                        img.draw(in: pageRect)
                    }
                }
                try? data.write(to: documentsURL.appendingPathComponent(name))
            }
            return name
        } else {
            let name = "\(id).png"
            if let data = images.first?.jpegData(compressionQuality: 0.9) {
                try? data.write(to: documentsURL.appendingPathComponent(name))
            }
            return name
        }
    }
    
    private func saveThumbnail(from image: UIImage?, id: String) -> String {
        let name = "\(id)_thumb.png"
        guard let image = image, let thumb = makeThumbnail(from: image, maxSide: 140) else { return name }
        if let data = thumb.pngData() {
            try? data.write(to: documentsURL.appendingPathComponent(name))
        }
        return name
    }
    
    private func makeThumbnail(from image: UIImage?, maxSide: CGFloat) -> UIImage? {
        guard let image = image else { return nil }
        let aspect = image.size.width / image.size.height
        let targetSize = aspect >= 1 ? CGSize(width: maxSide, height: maxSide / aspect) : CGSize(width: maxSide * aspect, height: maxSide)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    private func savePagesJSON(_ pages: [String], id: String) -> String {
        let name = "pages_\(id).json"
        if let data = try? JSONEncoder().encode(pages) {
            try? data.write(to: documentsURL.appendingPathComponent(name))
        }
        return name
    }
    
    private func saveFullText(_ pages: [String], id: String) -> String? {
        let text = pages.joined(separator: "\n\n")
        guard !text.isEmpty else { return nil }
        let name = "\(id).txt"
        try? text.data(using: .utf8)?.write(to: documentsURL.appendingPathComponent(name))
        return name
    }
}
