// LabelReadingViewController.swift
import UIKit
import AVFoundation

class LabelReadingViewController: UIViewController {

    var readingSession: ReadingSessionData?
    
    // MARK: - Outlets
    @IBOutlet weak var speakerButton: UIButton!
    @IBOutlet weak var StoryCollectionView: UICollectionView!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var storyTitleLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var retakeButton: UIButton!
    @IBOutlet weak var spacingStepper: UIStepper!
    @IBOutlet weak var spacingValueLabel: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    
    
    // MARK: - Data Source
    var story: Story?
    var scannedPages: [String]?
    var scannedTitle: String?
    var currentIndex: Int = 0
    var storyTextString: String = ""
    let speechSynthesizer = AVSpeechSynthesizer()
    var isSpeakingFromButton = false
    private var syllablePopover: UILabel?
    private var syllableOverlay: UIView?
    var currentWordSpacing: CGFloat = 1.0
    private var isRestartingSpeech = false
    
    private var cleanStoryText: String {
        return storyTextString.replacingOccurrences(of: "<CENTER>", with: "")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        if let stepper = spacingStepper {
            stepper.minimumValue = 1
            stepper.maximumValue = 5
            stepper.stepValue = 1
            stepper.value = 1
            stepper.wraps = false
            stepper.autorepeat = true
        }
        let brownColor = UIColor(red: 128/255, green: 87/255, blue: 55/255, alpha: 1.0)
        speakerButton.layer.borderColor = brownColor.cgColor
        speakerButton.layer.borderWidth = 3.0
        setSpeakerIcon()
        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        speakerButton.addGestureRecognizer(longPress)
        StoryCollectionView.dataSource = self
        StoryCollectionView.delegate   = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let st = scannedTitle {
            storyTitleLabel?.text = st
        } else {
            storyTitleLabel?.text = story?.title
            if let currentStory = story {
                if let currentStory = story {
                    StoryManager.shared.saveProgress(storyId: currentStory.id, pageIndex: currentIndex)
                }
            }
        }
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        StoryCollectionView.reloadData()
        updateProgress()
        updateChevronEnabledState()
        if isCurrentCheckpointCompleted() {
            retakeButton?.isHidden = false
        } else {
            retakeButton?.isHidden = true
        }
        let isUploads = scannedPages != nil

        spacingStepper?.isHidden = !isUploads
        spacingValueLabel?.isHidden = !isUploads
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startReadingSessionIfNeeded()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        endReadingSessionIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        speakerButton.layer.cornerRadius = speakerButton.bounds.height/2
        speakerButton.clipsToBounds = true
        StoryCollectionView.layoutIfNeeded()
        let cellHeight = StoryCollectionView.contentSize.height
        let availableHeight = StoryCollectionView.bounds.height
        
        if cellHeight < availableHeight {
             let inset = (availableHeight - cellHeight) / 2.0
             StoryCollectionView.contentInset = UIEdgeInsets(top: inset, left: 0, bottom: inset, right: 0)
        } else {
             StoryCollectionView.contentInset = .zero
        }
    }

    // MARK: - Actions
    @IBAction func spacingStepperChanged(_ sender: UIStepper) {
        let val = CGFloat(sender.value)
        currentWordSpacing = max(1.0, min(val, 5.0))
        StoryCollectionView.reloadData()
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    @IBAction func retakeCheckpointTapped(_ sender: UIButton) {
        let nextIndex = currentIndex + 1
        _ = navigateToCheckpoint(nextIndex: nextIndex, forceRetake: true)
    }

    @IBAction func speakerButtonTapped(_ sender: UIButton) {
        if speechSynthesizer.isPaused {
            speechSynthesizer.continueSpeaking()
            showPauseIcon()
            isSpeakingFromButton = true
            return
        }
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.pauseSpeaking(at: .immediate)
            showSpeakerIcon()
            isSpeakingFromButton = false
            return
        }
        let utterance = AVSpeechUtterance(string: cleanStoryText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = 0.35

        speechSynthesizer.delegate = self
        speechSynthesizer.speak(utterance)

        showPauseIcon()
        isSpeakingFromButton = true
    }

    @IBAction func homeTapped(_ sender: UIButton) {
        endReadingSessionIfNeeded()

        guard let nav = navigationController else { return }
        if let homeVC = nav.viewControllers.first {
            nav.setViewControllers([homeVC], animated: true)
        }
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
    
    private func setSpeakerIcon() {
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        let image = UIImage(systemName: "speaker.wave.2.fill", withConfiguration: config)
        speakerButton.setImage(image, for: .normal)
    }
    
    private func showPauseIcon() {
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        speakerButton.setImage(
            UIImage(systemName: "pause.fill", withConfiguration: config),
            for: .normal
        )
    }

    func showSpeakerIcon() {
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        speakerButton.setImage(
            UIImage(systemName: "speaker.wave.2.fill", withConfiguration: config),
            for: .normal
        )
    }

    func updateChevronEnabledState() {
            previousButton.isEnabled = currentIndex > 0
            
            let totalCount: Int
            if let pages = scannedPages {
                 totalCount = pages.count
            } else if let story = story {
                 totalCount = story.content.count
            } else {
                 totalCount = 0
            }
            
            if currentIndex < totalCount - 1 {
                nextButton.isEnabled = true
            } else {
                if isCurrentCheckpointCompleted() {
                    nextButton.isEnabled = false
                } else {
                    nextButton.isEnabled = true
                }
            }
        }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            showRestartPopup()
        }
    }
    @objc private func restartTapped() {
        view.viewWithTag(999)?.removeFromSuperview()

        isRestartingSpeech = true

        speechSynthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: cleanStoryText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = 0.35

        speechSynthesizer.delegate = self
        speechSynthesizer.speak(utterance)

        showPauseIcon()
        isSpeakingFromButton = true
    }

    private func showRestartPopup() {
        view.viewWithTag(999)?.removeFromSuperview()

        let popup = UIButton()
        popup.tag = 999

        popup.setTitle("Restart", for: .normal)
        popup.setTitleColor(
            UIColor(red: 128/255, green: 87/255, blue: 55/255, alpha: 1),
            for: .normal
        )
        popup.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)

        popup.backgroundColor = .systemBackground
        popup.layer.cornerRadius = 14
        popup.layer.borderWidth = 3
        popup.layer.borderColor = speakerButton.layer.borderColor
        popup.layer.shadowColor = UIColor.black.cgColor
        popup.layer.shadowOpacity = 0.2
        popup.layer.shadowOffset = CGSize(width: 0, height: 2)
        popup.layer.shadowRadius = 6

        popup.addTarget(self, action: #selector(restartTapped), for: .touchUpInside)

        let buttonFrame = speakerButton.convert(speakerButton.bounds, to: view)
        popup.frame = CGRect(
            x: buttonFrame.midX - 60,
            y: buttonFrame.minY - 50,
            width: 120,
            height: 44
        )

        view.addSubview(popup)
    }



}

// MARK: - CollectionView DataSource
extension LabelReadingViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "story_cell", for: indexPath) as! LabelCollectionViewCell
        cell.storyText.attributedText = attributedText(for: storyTextString, spacingLevel: currentWordSpacing)
        
        cell.storyText.numberOfLines = 0
        cell.storyText.isUserInteractionEnabled = true
        cell.storyText.gestureRecognizers?.forEach { cell.storyText.removeGestureRecognizer($0) }
        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLabelLongPress(_:))
        )
        longPress.minimumPressDuration = 0.35
        cell.storyText.addGestureRecognizer(longPress)

        return cell
    }
}

// MARK: - CollectionView Layout
extension LabelReadingViewController: UICollectionViewDelegateFlowLayout {
    private func naturalCellHeight(for width: CGFloat) -> CGFloat {
        let fixedLabelWidth: CGFloat = 599
        let attrString = attributedText(for: storyTextString, spacingLevel: currentWordSpacing)
        let boundingRect = attrString.boundingRect(
            with: CGSize(width: fixedLabelWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil)
        
        let textHeight = ceil(boundingRect.height) + 100
        return textHeight
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width
        let height = naturalCellHeight(for: width)
        return CGSize(width: width, height: height)
    }
}

// MARK: - Reading Session
private extension LabelReadingViewController {
    
        private func startReadingSessionIfNeeded() {
            guard readingSession == nil else { return }
            let sessionStoryId: String
            let sessionLevel: Int
            if let story = story {
                sessionStoryId = story.id
                sessionLevel = extractLevel(from: story.difficulty)
            }
            else if scannedPages != nil {
                sessionStoryId = scannedTitle ?? "Uploaded Document"
                sessionLevel = 1
            } else {
                return
            }

            let session = ReadingSessionData(
                id: UUID(),
                storyId: sessionStoryId,
                childId: "default_child",
                startTime: Date(),
                endTime: nil,
                levelUnlocked: sessionLevel
            )

            readingSession = session
            AnalyticsStore.shared.appendReadingSession(session)
            print("Reading session started for: \(sessionStoryId)")
        }
    
    func endReadingSessionIfNeeded() {
        guard let session = readingSession else { return }
        if session.endTime != nil { return }

        let now = Date()
        AnalyticsStore.shared.updateReadingSessionEnd(
            sessionId: session.id,
            endTime: now
        )

        readingSession?.endTime = now
        print("Reading session ended")
    }
    
    func extractLevel(from difficulty: String) -> Int {
        switch difficulty.lowercased() {
        case "level 1": return 1
        case "level 2": return 2
        case "level 3": return 3
        default: return 1
        }
    }
}

// MARK: - Text Formatting
private extension LabelReadingViewController {
    func fontForStory() -> UIFont {
        guard let story = story else {
            return UIFont(name: "ArialMT", size: 30)!
        }

        switch story.difficulty.lowercased() {
        case "level 1": return UIFont(name: "ArialMT", size: 32)!
        case "level 2": return UIFont(name: "TrebuchetMS", size: 30)!
        case "level 3": return UIFont(name: "TimesNewRomanPSMT", size: 30)!
        default: return UIFont.systemFont(ofSize: 30)
        }
    }
    
    func attributedText(for text: String, spacingLevel: CGFloat) -> NSAttributedString {
        let font = fontForStory()
        let safeLevel = max(1.0, min(spacingLevel, 5.0))
        let extraKern = (safeLevel - 1) * 10
        
        let result = NSMutableAttributedString()
        let lines = text.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 8
            
            var cleanLine = line
            if line.contains("<CENTER>") {
                style.alignment = .center
                cleanLine = line.replacingOccurrences(of: "<CENTER>", with: "")
            } else {
                style.alignment = .left
            }
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: style,
                .foregroundColor: UIColor.black
            ]
            
            let attrLine = NSMutableAttributedString(string: cleanLine, attributes: attributes)
            if extraKern > 0 {
                let nsLine = cleanLine as NSString
                nsLine.enumerateSubstrings(in: NSRange(location: 0, length: nsLine.length), options: .byWords) { _, range, _, _ in
                    let spacePosition = range.location + range.length
                    if spacePosition < nsLine.length {
                        let spaceRange = NSRange(location: spacePosition, length: 1)
                        attrLine.addAttribute(.kern, value: extraKern, range: spaceRange)
                    }
                }
            }
            
            result.append(attrLine)
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: [.font: font]))
            }
        }
        
        return result
    }
}

// MARK: - Navigation
private extension LabelReadingViewController {
    func makePageViewController(at index: Int) -> UIViewController {
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
            vc.readingSession = self.readingSession
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
            vc.readingSession = self.readingSession
            return vc
        } else {
            let vc = storyboard.instantiateViewController(
                withIdentifier: "LabelReadingVC"
            ) as! LabelReadingViewController

            vc.story = story
            vc.currentIndex = index
            vc.storyTextString = page.text
            vc.readingSession = self.readingSession
            return vc
        }
    }

    private func showStoryPage(at index: Int) {
        let nextVC = makePageViewController(at: index)

        if let nav = navigationController {
            var stack = nav.viewControllers
            stack[stack.count - 1] = nextVC
            nav.setViewControllers(stack, animated: false)
        }
    }
    

    func goToPage(offset: Int) {
            let totalCount = story?.content.count ?? 0
            let newIndex = currentIndex + offset

            if offset < 0 {
                if newIndex < 0 {
                    navigationController?.popViewController(animated: true)
                    return
                }
                showStoryPage(at: newIndex)
                return
            }

            if let story = story {
                let currentPage = story.content[currentIndex]
                
                if currentPage.checkAfter {
                    if !isCurrentCheckpointCompleted() {
                        if navigateToCheckpoint(nextIndex: newIndex) {
                            return
                        }
                    }
                }
            }

            if newIndex >= totalCount {
                if let currentStory = story {
                     StoryManager.shared.saveProgress(storyId: currentStory.id, pageIndex: currentIndex, didComplete: true)
                }
                popToReadingPreview()
                return
            }

            showStoryPage(at: newIndex)
        }
    
    func popToReadingPreview() {
        endReadingSessionIfNeeded()
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
    
    func popToUploads() {
        endReadingSessionIfNeeded()
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
}

// MARK: - Checkpoint Logic
private extension LabelReadingViewController {
    func isCurrentCheckpointCompleted() -> Bool {
        guard let story = story else { return false }
        let currentPage = story.content[currentIndex]
        guard currentPage.checkAfter else { return false }
        
        guard let item = StoryManager.shared.getCheckpointItem(storyId: story.id, pageNumber: currentPage.pageNumber) else { return false }
        
        return StoryManager.shared.isCheckpointCompleted(storyId: story.id, checkpointText: item.text)
    }
    
    func navigateToCheckpoint(nextIndex: Int, forceRetake: Bool = false) -> Bool {
            // 1. Safety check
            guard let currentStory = story else { return false }
            
            let currentPageNumber = currentStory.content[currentIndex].pageNumber
            
            guard let item = StoryManager.shared.getCheckpointItem(storyId: currentStory.id, pageNumber: currentPageNumber) else {
                return false
            }
            
            guard let storyboard = self.storyboard,
                  let cpVC = storyboard.instantiateViewController(withIdentifier: "CheckpointVC") as? CheckpointViewController else {
                return false
            }
            
            cpVC.story = currentStory
            cpVC.checkpointItem = item
            cpVC.nextPageIndex = nextIndex
            
            cpVC.fallbackPageIndex = firstPageAfterLastCheckpoint(currentIndex: currentIndex)
            
            cpVC.forceRetake = forceRetake
            cpVC.readingSession = self.readingSession
            
            cpVC.modalPresentationStyle = .fullScreen
            navigationController?.pushViewController(cpVC, animated: true)
            
            return true
        }
    
    func firstPageAfterLastCheckpoint(currentIndex: Int) -> Int {
        guard let story = story else { return 0 }
        let pages = story.content
        for i in stride(from: currentIndex - 1, through: 0, by: -1) {
            if pages[i].checkAfter {
                return i + 1
            }
        }
        return 0
    }
}

// MARK: - Syllable Interaction
private extension LabelReadingViewController {
    @objc private func handleLabelLongPress(_ recognizer: UILongPressGestureRecognizer) {

        guard recognizer.state == .began,
              let label = recognizer.view as? UILabel else { return }

        let point = recognizer.location(in: label)

        guard let (word, rect) = wordAtPoint(in: label, point: point) else { return }

        let syllableText = PhonemeEngine.kindleSplit(word)

        showSyllablePopover(
            text: syllableText,
            from: label,
            wordRectInLabel: rect
        )
    }
    
    private func hideSyllablePopover() {
        syllablePopover?.removeFromSuperview()
        syllableOverlay?.removeFromSuperview()
        syllablePopover = nil
        syllableOverlay = nil
    }
    
    @objc func handleOverlayTap(_ recognizer: UITapGestureRecognizer) {
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
    
    func showSyllablePopover(text: String, from label: UILabel, wordRectInLabel: CGRect) {
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
    
    func wordAtPoint(in label: UILabel, point: CGPoint) -> (word: String, rect: CGRect)? {
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
}
extension LabelReadingViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {

        if isRestartingSpeech {
            isRestartingSpeech = false
            return
        }

        showSpeakerIcon()
        isSpeakingFromButton = false
    }
}
