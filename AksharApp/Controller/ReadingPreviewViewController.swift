//
//  ReadingPreviewViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit


class ReadingPreviewViewController: UIViewController {
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
    
    private var storiesResponse = StoriesResponse()
        private var levelStories: [Story] = []
    
    private let difficultyLevels = ["Level 1","Level 2","Level 3"]
    private var levelIndex: Int = 0
    
    private func configureCard(index: Int, titleLabel: UILabel, imageView: UIImageView) {
        guard index < levelStories.count else {
            titleLabel.text = ""
            imageView.image = nil
            return
        }
        let story = levelStories[index]
        titleLabel.text = story.title
        imageView.image = UIImage(named: story.coverImage)
    }

    private func openStory(at index: Int) {
        guard index >= 0, index < levelStories.count else { return }

        let story = levelStories[index]
        guard let firstPage = story.content.first else { return }
        guard let storyboard = self.storyboard else { return }

        if let imageName = firstPage.imageURL, !imageName.isEmpty {
            let vc = storyboard.instantiateViewController(
                withIdentifier: "ImageLabelReadingVC"
            ) as! ImageLabelReadingViewController

            vc.story = story
            vc.currentIndex = 0
            vc.storyTextString = firstPage.text
            vc.imageName = imageName
            vc.story = story

            navigationController?.pushViewController(vc, animated: true)

        } else {
            let vc = storyboard.instantiateViewController(
                withIdentifier: "LabelReadingVC"
            ) as! LabelReadingViewController

            vc.story = story
            vc.currentIndex = 0
            vc.storyTextString = firstPage.text

            navigationController?.pushViewController(vc, animated: true)
    }

    }       

    private func loadCurrentLevel() {
        levelIndex = max(0, min(levelIndex, difficultyLevels.count - 1))
        let difficulty = difficultyLevels[levelIndex]
        levelStories = storiesResponse.getStories(difficulty: difficulty)
        
        configureCard(index: 0, titleLabel: title1, imageView: cover1)
        configureCard(index: 1, titleLabel: title2, imageView: cover2)
        configureCard(index: 2, titleLabel: title3, imageView: cover3)
        configureCard(index: 3, titleLabel: title4, imageView: cover4)

        levelLabel?.text = difficulty.capitalized
        prevLevelButton?.isEnabled = (levelIndex > 0)
        nextLevelButton?.isEnabled = (levelIndex < difficultyLevels.count - 1)
    }
    
    override func viewDidLoad() {
        print("🎯 ReadingPreviewViewController viewDidLoad")
        super.viewDidLoad()
        loadCurrentLevel()
        
        let customYellow = UIColor(red: 250/255, green: 239/255, blue: 184/255, alpha: 1.0)
        
        
        card1bg_view.layer.cornerRadius = 25
        card1bg_view.layer.borderColor = customYellow.cgColor
        card1bg_view.layer.borderWidth = 7.0
        
        cover1.layer.cornerRadius = 25
        
        card2bg_view.layer.cornerRadius = 25
        card2bg_view.layer.borderColor = customYellow.cgColor
        card2bg_view.layer.borderWidth = 7.0
        
        cover2.layer.cornerRadius = 25
        
        card3bg_view.layer.cornerRadius = 25
        card3bg_view.layer.borderColor = customYellow.cgColor
        card3bg_view.layer.borderWidth = 7.0
        
        cover3.layer.cornerRadius = 25
        
        card4bg_view.layer.cornerRadius = 25
        card4bg_view.layer.borderColor = customYellow.cgColor
        card4bg_view.layer.borderWidth = 7.0
        
        cover4.layer.cornerRadius = 25
                levelStories = storiesResponse.getStories(difficulty: "Level 1")
                if levelStories.count > 0 { configureCard(index: 0, titleLabel: title1, imageView: cover1) }
                if levelStories.count > 1 { configureCard(index: 1, titleLabel: title2, imageView: cover2) }
                if levelStories.count > 2 { configureCard(index: 2, titleLabel: title3, imageView: cover3) }
                if levelStories.count > 3 { configureCard(index: 3, titleLabel: title4, imageView: cover4) }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    @IBAction func prevLevelTapped(_ sender: UIButton) {
        guard levelIndex > 0 else { return }
        levelIndex -= 1
        loadCurrentLevel()
        UIView.transition(with: view, duration: 0.25, options: .transitionCrossDissolve, animations: nil)
    }

    @IBAction func nextLevelTapped(_ sender: UIButton) {
        guard levelIndex < difficultyLevels.count - 1 else { return }
        levelIndex += 1
        loadCurrentLevel()
        UIView.transition(with: view, duration: 0.25, options: .transitionCrossDissolve, animations: nil)
    }
    
    @IBAction func backToHomeTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }


    @IBAction func readCard1Tapped(_ sender: UIButton) {
        print("pressed")
        openStory(at: 0)
    }
    @IBAction func readCard2Tapped(_ sender: UIButton) {
        openStory(at: 1)
    }
    
    @IBAction func readCard3Tapped(_ sender: UIButton) {
        openStory(at: 2)
    }
    @IBAction func readCard4Tapped(_ sender: UIButton) {
        openStory(at: 3)
    }
    
}
