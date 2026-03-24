import UIKit

final class ReadingPreviewViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var cover4: UIImageView!
    @IBOutlet weak var cover3: UIImageView!
    @IBOutlet weak var card3bg_view: UIView!
    @IBOutlet weak var card4bg_view: UIView!
    @IBOutlet weak var title4: UILabel!
    @IBOutlet weak var title3: UILabel!
    @IBOutlet weak var title2: UILabel!
    @IBOutlet weak var title1: UILabel!
    @IBOutlet weak var card2bg_view: UIView!
    @IBOutlet weak var cover2: UIImageView!
    @IBOutlet weak var cover1: UIImageView!
    @IBOutlet weak var card1bg_view: UIView!
    @IBOutlet weak var prevLevelButton: UIButton!
    @IBOutlet weak var nextLevelButton: UIButton!
    @IBOutlet weak var levelLabel: UILabel!

    @IBOutlet weak var progress1: UIProgressView!
    @IBOutlet weak var progress2: UIProgressView!
    @IBOutlet weak var progress3: UIProgressView!
    @IBOutlet weak var progress4: UIProgressView!

    @IBOutlet weak var readButton4: UIButton!
    @IBOutlet weak var readButton3: UIButton!
    @IBOutlet weak var readButton2: UIButton!
    @IBOutlet weak var readButton1: UIButton!
    
    // MARK: - Injected
    var storyManager: StoryManager!
    var childManager: ChildManager!
    var checkpointHistoryManager: CheckpointHistoryManager!

    private let difficultyLevels = ["Level 1", "Level 2", "Level 3"]

    private var levelStories: [Story] = []
    private var levelIndex = 0
    private var cardViews: [UIView] = []

    // MARK: - Glow Effect Properties
    private var idleTimer: Timer?
    private var glowStopTimer: Timer?

    private let initialIdleDelay: TimeInterval = 2
    private let glowDuration: TimeInterval = 4
    private let gapBetweenGlows: TimeInterval = 4

    private var highlightedIndexPath: IndexPath?

    // MARK: - Lifecycle
    private func verifyDependencies() {
        assert(storyManager != nil, "storyManager was not injected into \(type(of: self))")
        assert(childManager != nil, "childManager was not injected into \(type(of: self))")
        assert(checkpointHistoryManager != nil, "checkpointHistoryManager was not injected into \(type(of: self))")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        verifyDependencies()
        cardViews = [card1bg_view, card2bg_view, card3bg_view, card4bg_view]
        styleCards()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        loadCurrentLevel()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startIdleTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        idleTimer?.invalidate()
        glowStopTimer?.invalidate()
        cancelHighlight()
    }

    // MARK: - Level Handling
    private func loadCurrentLevel() {
        levelLabel.text = difficultyLevels[levelIndex]
       
        levelStories = storyManager.getStories(for: difficultyLevels[levelIndex])
        
        setupCards()
        updateChevronStates()
    }
    
    private func setupCards() {
        let covers = [cover1, cover2, cover3, cover4]
        let titles = [title1, title2, title3, title4]
        let backgrounds = [card1bg_view, card2bg_view, card3bg_view, card4bg_view]
        let progressViews = [progress1, progress2, progress3, progress4]
        let buttons = [readButton1, readButton2, readButton3, readButton4]

        for i in 0..<4 {
            guard let cover = covers[i], let title = titles[i],
                  let bg = backgrounds[i], let progress = progressViews[i],
                  let button = buttons[i] else { continue }

            if i < levelStories.count {
                let story = levelStories[i]
                
                bg.isHidden = false
                title.text = story.title
                cover.image = UIImage(named: story.coverImage)
                
                bg.layer.cornerRadius = 20
                cover.layer.cornerRadius = 20
                bg.layer.masksToBounds = false
                
                updateReadButton(button: button, progressView: progress, story: story)
                
            } else {
                bg.isHidden = true
            }
        }
    }
    
    private func updateChevronStates() {
        prevLevelButton.isEnabled = levelIndex > 0
        prevLevelButton.alpha = levelIndex > 0 ? 1.0 : 0.4
        
        nextLevelButton.isEnabled = levelIndex < difficultyLevels.count - 1
        nextLevelButton.alpha = levelIndex < difficultyLevels.count - 1 ? 1.0 : 0.4
    }
    
    private func updateReadButton(button: UIButton, progressView: UIProgressView, story: Story) {

        let (savedIndex, isCompleted) = storyManager.getProgress(for: story.id)
        let totalPages = max(1, story.content.count)

        var title = "Read"

        if isCompleted {
            title = "Read Again"
            progressView.progress = 1.0
            progressView.isHidden = false
        }
        else if savedIndex > 0 {
            title = "Continue"
            progressView.progress = Float(savedIndex) / Float(totalPages)
            progressView.isHidden = false
        }
        else {
            title = "Read"
            progressView.progress = 0.0
            progressView.isHidden = true
        }

        let font = UIFont.systemFont(ofSize: 20, weight: .semibold)

        let attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: font]
        )

        button.setAttributedTitle(attributedTitle, for: .normal)
    }
    
    // MARK: - Glow Effect
    private func startIdleTimer() {

        idleTimer?.invalidate()

        idleTimer = Timer.scheduledTimer(
            withTimeInterval: initialIdleDelay,
            repeats: false
        ) { [weak self] _ in
            self?.startGlowCycle()
        }
    }
    
    private func startGlowCycle() {

        triggerHighlightIfNeeded()

        glowStopTimer?.invalidate()
        glowStopTimer = Timer.scheduledTimer(
            withTimeInterval: glowDuration,
            repeats: false
        ) { [weak self] _ in
            self?.stopGlowAndScheduleNext()
        }
    }
    
    private func triggerHighlightIfNeeded() {

        let difficulty = difficultyLevels[levelIndex]

        guard let index = storyManager.indexToHighlight(for: difficulty) else { return }

        highlightedIndexPath = IndexPath(item: index, section: 0)

        let targetView = cardViews[index]

        targetView.layoutIfNeeded()

        startGlowAnimation(on: targetView)
        startPopAnimation(on: targetView)
    }
    
    private func stopGlowAndScheduleNext() {

        cancelHighlight()

        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(
            withTimeInterval: gapBetweenGlows,
            repeats: false
        ) { [weak self] _ in
            self?.startGlowCycle()
        }
    }
    
    private func startGlowAnimation(on view: UIView) {

        view.layer.shadowColor = UIColor.systemYellow.cgColor
        view.layer.shadowRadius = 12
        view.layer.shadowOffset = .zero

        let anim = CABasicAnimation(keyPath: "shadowOpacity")
        anim.fromValue = 0
        anim.toValue = 0.9
        anim.duration = 1.0
        anim.autoreverses = true
        anim.repeatCount = .infinity

        view.layer.add(anim, forKey: "glow")
    }
    
    private func startPopAnimation(on view: UIView) {

        let anim = CABasicAnimation(keyPath: "transform.scale")
        anim.fromValue = 1
        anim.toValue = 1.04
        anim.duration = 1.0
        anim.autoreverses = true
        anim.repeatCount = .infinity

        view.layer.add(anim, forKey: "pop")
    }
    
    private func cancelHighlight() {

        if let index = highlightedIndexPath?.item {

            let view = cardViews[index]

            view.layer.removeAnimation(forKey: "glow")
            view.layer.removeAnimation(forKey: "pop")
        }

        highlightedIndexPath = nil
    }
    
    // MARK: - Navigation
        private func openStory(at index: Int) {
            guard index < levelStories.count,
                  let storyboard = storyboard else { return }
            
            let story = levelStories[index]
            
            let (savedIndex, isCompleted) = storyManager.getProgress(for: story.id)
            
            let pageIndex = isCompleted ? 0 : min(max(0, savedIndex), story.content.count - 1)
            let page = story.content[pageIndex]
            
            if let imageName = page.imageURL, !imageName.isEmpty {
                guard let vc = storyboard.instantiateViewController(withIdentifier: "ImageLabelReadingVC") as? ImageLabelReadingViewController else { return }
                vc.story = story
                vc.currentIndex = pageIndex
                vc.storyTextString = page.text
                vc.imageName = imageName
                vc.storyManager = storyManager
                vc.childManager = childManager
                vc.checkpointHistoryManager = checkpointHistoryManager
                navigationController?.pushViewController(vc, animated: true)
            } else {
                guard let vc = storyboard.instantiateViewController(withIdentifier: "LabelReadingVC") as? LabelReadingViewController else { return }
                vc.story = story
                vc.currentIndex = pageIndex
                vc.storyTextString = page.text
                vc.storyManager = storyManager
                vc.childManager = childManager
                vc.checkpointHistoryManager = checkpointHistoryManager
                navigationController?.pushViewController(vc, animated: true)
            }
        }

    // MARK: - Styling
    private func styleCards() {
        let borderColor = UIColor(
            red: 250/255,
            green: 239/255,
            blue: 184/255,
            alpha: 1
        ).cgColor

        styleCard(card1bg_view, cover: cover1, borderColor: borderColor)
        styleCard(card2bg_view, cover: cover2, borderColor: borderColor)
        styleCard(card3bg_view, cover: cover3, borderColor: borderColor)
        styleCard(card4bg_view, cover: cover4, borderColor: borderColor)
    }

    private func styleCard(_ background: UIView, cover: UIImageView, borderColor: CGColor) {
        background.layer.cornerRadius = 25
        background.layer.borderWidth = 7
        background.layer.borderColor = borderColor

        cover.layer.cornerRadius = 25
        cover.clipsToBounds = true
    }

    // MARK: - Actions
    @IBAction func prevLevelTapped(_ sender: UIButton) {
        guard levelIndex > 0 else { return }
        levelIndex -= 1
        loadCurrentLevel()
        animateLevelChange()
    }

    @IBAction func nextLevelTapped(_ sender: UIButton) {
        guard levelIndex < difficultyLevels.count - 1 else { return }
        levelIndex += 1
        loadCurrentLevel()
        animateLevelChange()
    }

    @IBAction func backToHomeTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func readCard1Tapped(_ sender: UIButton) { openStory(at: 0) }
    @IBAction func readCard2Tapped(_ sender: UIButton) { openStory(at: 1) }
    @IBAction func readCard3Tapped(_ sender: UIButton) { openStory(at: 2) }
    @IBAction func readCard4Tapped(_ sender: UIButton) { openStory(at: 3) }

    private func animateLevelChange() {
        UIView.transition(
            with: view,
            duration: 0.25,
            options: .transitionCrossDissolve,
            animations: nil
        )
    }
}
