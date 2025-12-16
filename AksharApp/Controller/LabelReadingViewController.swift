// LabelReadingViewController.swift
import UIKit
import AVFoundation

class LabelReadingViewController: UIViewController {

    @IBOutlet weak var speakerButton: UIButton!
    @IBOutlet weak var StoryCollectionView: UICollectionView!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var storyTitleLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!

    // MARK: - Data Source
    var story: Story!
    
    var scannedPages: [String]?
    var scannedTitle: String?

    var currentIndex: Int = 0
    var storyTextString: String = ""
    let speechSynthesizer = AVSpeechSynthesizer()
    private var syllablePopover: UILabel?
    private var syllableOverlay: UIView?

    
    private func fontForStory() -> UIFont {
        guard let story = story else {
            return UIFont(name: "ArialMT", size: 30)!
        }

        switch story.difficulty.lowercased() {
        case "level 1":
            return UIFont(name: "ArialMT", size: 32)!
        case "level 2":
            return UIFont(name: "TrebuchetMS", size: 30)!
        case "level 3":
            return UIFont(name: "TimesNewRomanPSMT", size: 30)!
        default:
            return UIFont.systemFont(ofSize: 30)
        }
    }

    private func makePageViewController(at index: Int) -> UIViewController {
        guard let storyboard = self.storyboard else {
            fatalError("No storyboard in LabelReadingViewController")
        }

        if let pages = scannedPages {
            let pageText = pages[index]

            let vc = storyboard.instantiateViewController(
                withIdentifier: "LabelReadingVC"
            ) as! LabelReadingViewController

            vc.scannedPages = pages
            vc.scannedTitle = scannedTitle
            vc.currentIndex = index
            vc.storyTextString = pageText
            return vc
        }


        guard let story = story else { fatalError("Neither story nor scannedPages provided") }
        
        let page = story.content[index]

        if let imageName = page.imageURL, !imageName.isEmpty {
            let vc = storyboard.instantiateViewController(
                withIdentifier: "ImageLabelReadingVC"
            ) as! ImageLabelReadingViewController
            vc.story = story
            vc.currentIndex = index
            vc.storyTextString = page.text
            vc.imageName = imageName
            return vc
        } else {
            let vc = storyboard.instantiateViewController(
                withIdentifier: "LabelReadingVC"
            ) as! LabelReadingViewController

            vc.story = story
            vc.currentIndex = index
            vc.storyTextString = page.text
            return vc
        }
    }
    private func firstPageAfterLastCheckpoint(currentIndex: Int) -> Int {
        let pages = story.content
        for i in stride(from: currentIndex - 1, through: 0, by: -1) {
            if pages[i].checkAfter {
                return i + 1
            }
        }
        return 0
    }

 
    @objc private func handleOverlayTap(_ recognizer: UITapGestureRecognizer) {
        guard let overlay = syllableOverlay,
              let pop = syllablePopover else { return }
        let location = recognizer.location(in: overlay)

        if !pop.frame.contains(location) {
            pop.removeFromSuperview()
            overlay.removeFromSuperview()
            syllablePopover = nil
            syllableOverlay = nil
        }
    }

    @objc private func handleLabelDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard let label = recognizer.view as? UILabel else { return }
        let pointInLabel = recognizer.location(in: label)
        guard let (word, wordRectInLabel) = wordAtPoint(in: label, point: pointInLabel) else { return }
        let syllableText = syllabify(word)

        showSyllablePopover(text: syllableText, from: label, wordRectInLabel: wordRectInLabel)
    }

    private func showSyllablePopover(text: String, from label: UILabel, wordRectInLabel: CGRect) {
        syllablePopover?.removeFromSuperview()
        syllableOverlay?.removeFromSuperview()
        syllablePopover = nil
        syllableOverlay = nil

        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleOverlayTap(_:)))
        overlay.addGestureRecognizer(tap)
        view.addSubview(overlay)
        syllableOverlay = overlay

        let popLabel = UILabel()
        popLabel.text = text
        popLabel.font = label.font.withSize(30)
        popLabel.textColor = UIColor.white
        popLabel.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        popLabel.numberOfLines = 0
        popLabel.textAlignment = NSTextAlignment.center
        popLabel.layer.cornerRadius = 10
        popLabel.clipsToBounds = true

        let maxWidth = view.bounds.width - 40
        let fittingSize = popLabel.sizeThatFits(CGSize(width: maxWidth - 24, height: CGFloat.greatestFiniteMagnitude))

        popLabel.frame.size = CGSize(width: fittingSize.width + 24, height: fittingSize.height + 16)

        let wordRectInView = label.convert(wordRectInLabel, to: overlay)
        var popOriginX = wordRectInView.midX - popLabel.frame.width / 2
        let tentativeY = wordRectInView.minY - popLabel.frame.height - 8

        popOriginX = max(8, min(popOriginX, overlay.bounds.width - popLabel.frame.width - 8))
        let popOriginY = max(8, tentativeY)
        popLabel.frame.origin = CGPoint(x: popOriginX, y: popOriginY)
        overlay.addSubview(popLabel)
        syllablePopover = popLabel
    }

    private func syllabify(_ word: String) -> String {
        let vowels = "aeiouAEIOU"
        var result: [String] = []
        var current = ""
        let chars = Array(word)
        for i in 0..<chars.count {
            let ch = chars[i]
            current.append(ch)
            if vowels.contains(ch), i < chars.count - 1 {
                result.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result.joined(separator: "‧")
    }

    private func showStoryPage(at index: Int) {
        let nextVC = makePageViewController(at: index)
        if let nav = navigationController {
            var stack = nav.viewControllers
            stack[stack.count - 1] = nextVC
            nav.setViewControllers(stack, animated: false)
        } else {
            present(nextVC, animated: true, completion: nil)
        }
    }
    
    private func popToReadingPreview() {
        guard let nav = navigationController else {
            dismiss(animated: true)
            return
        }

        for vc in nav.viewControllers {
            if vc is ReadingPreviewViewController {
                nav.popToViewController(vc, animated: true)
                return
            }
        }

        nav.popToRootViewController(animated: true)
    }
    private func popToUploads() {
        guard let nav = navigationController else {
            dismiss(animated: true)
            return
        }

        for vc in nav.viewControllers {
            if vc is UploadsViewController {
                nav.popToViewController(vc, animated: true)
                return
            }
        }
        nav.popToRootViewController(animated: true)
    }
    private func attributedTextForScannedPage(_ text: String) -> NSAttributedString {
        let font = UIFont(name: "ArialMT", size: 30)!
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [.font: font]
        )

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        nsText.enumerateSubstrings(
            in: fullRange,
            options: [.byWords, .substringNotRequired]
        ) { _, range, _, _ in
            let spaceRange = NSRange(location: range.location + range.length, length: 1)
            if spaceRange.location < nsText.length {
                attributed.addAttribute(
                    .kern,
                    value: 15,
                    range: spaceRange
                )
            }
        }

        return attributed
    }



    private func updateProgress() {
        let totalPages: Int
        if let pages = scannedPages {
            totalPages = pages.count
        } else if let story = story {
            totalPages = story.content.count
        } else {
            totalPages = 0
        }
        
        guard totalPages > 0 else {
            progressView?.progress = 0
            return
        }

        let progress = Float(currentIndex + 1) / Float(totalPages)
        progressView?.progress = progress
    }
    
    // MARK: - Checkpoint Navigation Logic

    private func navigateToCheckpoint(nextIndex: Int) -> Bool {
        guard let story = story else { return false }
        
        let response = CheckpointsResponse()
        let currentPageNumber = story.content[currentIndex].pageNumber
        
        guard let item = response.item(for: story.id, pageNumber: currentPageNumber) else {
            return false
        }
        
        guard let storyboard = self.storyboard,
              let cpVC = storyboard.instantiateViewController(withIdentifier: "CheckpointVC") as? CheckpointViewController else {
            return false
        }
        
        cpVC.story = self.story
        cpVC.checkpointItem = item
        cpVC.nextPageIndex = nextIndex
        cpVC.fallbackPageIndex = firstPageAfterLastCheckpoint(currentIndex: currentIndex)
        
        if let nav = navigationController {
            cpVC.modalPresentationStyle = .fullScreen
            navigationController?.pushViewController(cpVC, animated: true)
        } else {
            navigationController?.pushViewController(cpVC, animated: true)
        }
        
        return true
    }

    // MARK: - Page Navigator
    
    func goToPage(offset: Int) {
        let totalCount: Int
        if let pages = scannedPages {
            totalCount = pages.count
        } else if let story = story {
            totalCount = story.content.count
        } else {
            return
        }

        let newIndex = currentIndex + offset

        if offset < 0 {
            if newIndex < 0 {
                if let nav = navigationController {
                    nav.popViewController(animated: true)
                } else {
                    dismiss(animated: true, completion: nil)
                }
                return
            }
            guard newIndex < totalCount else { return }
            showStoryPage(at: newIndex)
            return
        }

        if let story = story {
            let currentPage = story.content[currentIndex]
            if currentPage.checkAfter {
                if navigateToCheckpoint(nextIndex: newIndex) {
                    return
                }
            }
        }

        guard newIndex < totalCount else {return}
        showStoryPage(at: newIndex)
    }

    private func updateChevronEnabledState() {
        previousButton.isEnabled = currentIndex > 0
    }

    private func wordAtPoint(in label: UILabel, point: CGPoint) -> (word: String, rect: CGRect)? {
        let attributedText: NSAttributedString
        if let attr = label.attributedText {
            attributedText = attr
        } else if let text = label.text {
            attributedText = NSAttributedString(string: text, attributes: [.font: label.font as Any])
        } else {
            return nil
        }

        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: label.bounds.size)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = label.numberOfLines
        textContainer.lineBreakMode = label.lineBreakMode
        layoutManager.addTextContainer(textContainer)

        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)

        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        if characterIndex >= textStorage.length { return nil }
        let string = attributedText.string as NSString
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)

        var start = characterIndex
        var end = characterIndex

        while start > 0 {
            let c = string.character(at: start - 1)
            if separators.contains(UnicodeScalar(c)!) { break }
            start -= 1
        }

        while end < string.length {
            let c = string.character(at: end)
            if separators.contains(UnicodeScalar(c)!) { break }
            end += 1
        }

        let range = NSRange(location: start, length: end - start)
        if range.length == 0 { return nil }
        let word = string.substring(with: range)

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let wordRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        return (word, wordRect)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let brownColor = UIColor(red: 128/255, green: 87/255, blue: 55/255, alpha: 1.0)
        speakerButton.layer.borderColor = brownColor.cgColor
        speakerButton.layer.borderWidth = 3.0
        StoryCollectionView.dataSource = self
        StoryCollectionView.delegate   = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let st = scannedTitle {
            storyTitleLabel?.text = st
        } else {
            storyTitleLabel?.text = story?.title
        }
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        StoryCollectionView.reloadData()
        updateProgress()
        updateChevronEnabledState()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let layout = StoryCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }

        layout.invalidateLayout()
        StoryCollectionView.layoutIfNeeded()
        let indexPath = IndexPath(item: 0, section: 0)
        guard let attributes = layout.layoutAttributesForItem(at: indexPath) else { return }
        let cellHeight = attributes.frame.height
        let availableHeight = StoryCollectionView.bounds.height

        let inset = max(0, (availableHeight - cellHeight) / 2.0)
        StoryCollectionView.contentInset = UIEdgeInsets(top: inset, left: 0, bottom: inset, right: 0)
    }

    @IBAction func speakerButtonTapped(_ sender: UIButton) {
        speechSynthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: storyTextString)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        speechSynthesizer.speak(utterance)
    }

    @IBAction func homeTapped(_ sender: UIButton) {
        navigationController?.popToRootViewController(animated: true)
    }

    @IBAction func previousTapped(_ sender: UIButton) {
        goToPage(offset: -1)
    }

    @IBAction func nextTapped(_ sender: UIButton) {
        goToPage(offset: 1)
    }

    @IBAction func backToPreviewTapped(_ sender: UIButton) {
        if scannedPages != nil {
            popToUploads()
            return
        }
        popToReadingPreview()
    }
}

extension LabelReadingViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "story_cell", for: indexPath) as! LabelCollectionViewCell
        if scannedPages != nil {
            cell.storyText.attributedText = attributedTextForScannedPage(storyTextString)
        } else {
            cell.storyText.attributedText = nil
            cell.storyText.text = storyTextString
            cell.storyText.font = fontForStory()
        }
        cell.storyText.textAlignment = .left
        cell.storyText.numberOfLines = 0
        cell.storyText.isUserInteractionEnabled = true
        
        cell.storyText.gestureRecognizers?.forEach { cell.storyText.removeGestureRecognizer($0) }
        let doubleTap = UITapGestureRecognizer(target: self, action:#selector(handleLabelDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        cell.storyText.addGestureRecognizer(doubleTap)
        return cell
    }
}

extension LabelReadingViewController: UICollectionViewDelegateFlowLayout {
    private func naturalCellHeight(for width: CGFloat) -> CGFloat {
        let sidePadding: CGFloat   = 40
        let topPadding: CGFloat    = 40
        let bottomPadding: CGFloat = 40
        let textWidth = width - sidePadding * 2
        let font = fontForStory()
        let boundingRect = (storyTextString as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil)
        
        let textHeight = ceil(boundingRect.height) + 40
        return topPadding + textHeight + bottomPadding
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width
        let height = naturalCellHeight(for: width)
        return CGSize(width: width, height: height)
    }
}
