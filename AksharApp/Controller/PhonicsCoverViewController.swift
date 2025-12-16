//
//  PhonicsCoverViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 09/12/25.
//

import UIKit

class PhonicsCoverViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var coverImageView: UIImageView!
    
    @IBOutlet weak var subtitleLabel: UILabel!
    var chosenExercise: ExerciseType!
    var resumeQuestionIndex: Int?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        coverImageView.image = UIImage(named: chosenExercise.coverImageName)
        titleLabel.text = chosenExercise.titleText
        subtitleLabel.text = chosenExercise.subtitleText

        // Do any additional setup after loading the view.
    }
    @IBAction func startButtonTapped(_ sender: UIButton) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(
            withIdentifier: chosenExercise.storyboardID
        )

        if var receiver = vc as? ExerciseReceivesCover {
            receiver.exerciseType = chosenExercise
            receiver.coverWasShown = true
        }

        if var resumable = vc as? ExerciseResumable {
            resumable.startingIndex = resumeQuestionIndex ?? 0
        }

        navigationController?.pushViewController(vc, animated: false)

    }
    

    @IBAction func homeButtonTapped(_ sender: Any) {
        goHomeFromPhonics()
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
