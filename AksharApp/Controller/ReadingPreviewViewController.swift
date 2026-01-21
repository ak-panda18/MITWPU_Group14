//
//  ReadingPreviewViewController.swift
//  AksharApp
//

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
    // MARK: - Properties

    private let storiesResponse = StoriesResponse()
    private let difficultyLevels = ["Level 1", "Level 2", "Level 3"]

    private var levelStories: [Story] = []
    private var levelIndex = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        styleCards()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        loadCurrentLevel()
    }

    // MARK: - Level Handling

    private func loadCurrentLevel() {
        levelIndex = max(0, min(levelIndex, difficultyLevels.count - 1))
        let difficulty = difficultyLevels[levelIndex]

        levelStories = storiesResponse.getStories(difficulty: difficulty)

        configureCard(
            index: 0,
            titleLabel: title1,
            imageView: cover1,
            progressView: progress1,
            readButton: readButton1
        )

        configureCard(
            index: 1,
            titleLabel: title2,
            imageView: cover2,
            progressView: progress2,
            readButton: readButton2
        )

        configureCard(
            index: 2,
            titleLabel: title3,
            imageView: cover3,
            progressView: progress3,
            readButton: readButton3
        )

        configureCard(
            index: 3,
            titleLabel: title4,
            imageView: cover4,
            progressView: progress4,
            readButton: readButton4
        )


        levelLabel.text = difficulty
        prevLevelButton.isEnabled = levelIndex > 0
        nextLevelButton.isEnabled = levelIndex < difficultyLevels.count - 1
    }

    // MARK: - Card Configuration

    private func configureCard(
        index: Int,
        titleLabel: UILabel,
        imageView: UIImageView,
        progressView: UIProgressView,
        readButton: UIButton
    ) {
        guard index < levelStories.count else {
            titleLabel.text = ""
            imageView.image = nil
            progressView.isHidden = true
            return
        }

        let story = levelStories[index]
        titleLabel.text = story.title
        imageView.image = UIImage(named: story.coverImage)
        updateProgress(for: story, progressView: progressView)
        let savedIndex = UserDefaults.standard.integer(
            forKey: progressKey(for: story)
        )

        let hasCompleted =
            UserDefaults.standard.bool(forKey: completedKey(for: story))
            || savedIndex >= story.content.count - 1

        if savedIndex >= story.content.count - 1 {
            UserDefaults.standard.set(true, forKey: completedKey(for: story))
        }

        var config = readButton.configuration ?? .filled()

        config.title = hasCompleted ? "Read Again" : "Read"

        config.titleTextAttributesTransformer =
            UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                let baseFont = UIFont.systemFont(ofSize: 23, weight: .medium)
                if let descriptor = baseFont.fontDescriptor.withDesign(.rounded) {
                    outgoing.font = UIFont(descriptor: descriptor, size: 23)
                }
                return outgoing
            }
        readButton.configuration = config
    }

    private func updateProgress(for story: Story, progressView: UIProgressView) {
        let totalPages = max(story.content.count, 1)

        let isCompleted = UserDefaults.standard.bool(
            forKey: completedKey(for: story)
        )

        if isCompleted {
            progressView.progress = 1.0
        } else {
            let savedIndex = UserDefaults.standard.integer(
                forKey: progressKey(for: story)
            )
            progressView.progress = Float(savedIndex + 1) / Float(totalPages)
        }

        progressView.isHidden = false
    }

    // MARK: - Navigation

    private func openStory(at index: Int) {
        guard index < levelStories.count,
              let storyboard = storyboard else { return }

        let story = levelStories[index]
        let savedIndex = UserDefaults.standard.integer(forKey: progressKey(for: story))
        let isCompleted = savedIndex >= story.content.count - 1
        let pageIndex = isCompleted ? 0 : min(max(0, savedIndex), story.content.count - 1)
        let page = story.content[pageIndex]

        if let imageName = page.imageURL, !imageName.isEmpty {
            let vc = storyboard.instantiateViewController(
                withIdentifier: "ImageLabelReadingVC"
            ) as! ImageLabelReadingViewController

            vc.story = story
            vc.currentIndex = pageIndex
            vc.storyTextString = page.text
            vc.imageName = imageName
            navigationController?.pushViewController(vc, animated: true)
        } else {
            let vc = storyboard.instantiateViewController(
                withIdentifier: "LabelReadingVC"
            ) as! LabelReadingViewController

            vc.story = story
            vc.currentIndex = pageIndex
            vc.storyTextString = page.text
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

    // MARK: - Helpers
    private func progressKey(for story: Story) -> String {
        "StoryProgress_\(story.title.replacingOccurrences(of: " ", with: ""))"
    }
    
    private func completedKey(for story: Story) -> String {
        "StoryCompleted_\(story.title.replacingOccurrences(of: " ", with: ""))"
    }

    private func replayStartedKey(for story: Story) -> String {
        "StoryReplayStarted_\(story.title.replacingOccurrences(of: " ", with: ""))"
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
