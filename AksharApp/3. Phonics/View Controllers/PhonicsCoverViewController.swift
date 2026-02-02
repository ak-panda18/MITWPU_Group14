//
//  PhonicsCoverViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 09/12/25.
//

import UIKit

class PhonicsCoverViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    // MARK: - Properties
    var chosenExercise: ExerciseType!
    var resumeCyclePointer: Int?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        chosenExercise = chosenExercise ?? ExerciseType.allCases.first
        
        coverImageView.image = UIImage(named: chosenExercise.coverImageName)
        titleLabel.text = chosenExercise.titleText
        subtitleLabel.text = chosenExercise.subtitleText
    }
    
    // MARK: - Actions
    @IBAction func startButtonTapped(_ sender: UIButton) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: chosenExercise.storyboardID)
        if var receiver = vc as? ExerciseReceivesCover {
            receiver.exerciseType = chosenExercise
            receiver.coverWasShown = true
        }

        if var resumable = vc as? ExerciseResumable {
            resumable.startingIndex = resumeCyclePointer ?? 0
        }

        navigationController?.pushViewController(vc, animated: false)
    }

    @IBAction func homeButtonTapped(_ sender: Any) {
        guard let nav = navigationController else { return }

        if let homeVC = nav.viewControllers.first(where: { $0 is HomeViewController }) {
            nav.popToViewController(homeVC, animated: true)
        }
    }
}
