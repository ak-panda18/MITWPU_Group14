//
//  HomeViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class HomeViewController: UIViewController {
    
    // MARK: - Properties
    private var phonicsExerciseCycle: RandomizedQuestionCycle!
    private let phonicsCycleKey = "phonics_exercise_cycle_v3"

    // MARK: - Outlets
    @IBOutlet weak var readingView: UIView!
    @IBOutlet weak var writingView: UIView!
    @IBOutlet weak var phonicsView: UIView!
    @IBOutlet weak var ocrView: UIView!
    @IBOutlet weak var analytics: UIButton!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPhonicsCycle()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        let menuViews = [readingView, writingView, phonicsView, ocrView]
        let brownBorderColor = UIColor.systemBrown.cgColor
        
        menuViews.forEach { view in
            view?.layer.cornerRadius = 25
            view?.layer.borderColor = brownBorderColor
            view?.layer.borderWidth = 2.0
            
        }
    }
    
    private func setupPhonicsCycle() {
        if let saved = ExerciseCycleStore.load(key: phonicsCycleKey) {
            phonicsExerciseCycle = saved
        } else {
            phonicsExerciseCycle = RandomizedQuestionCycle(
                count: ExerciseType.allCases.count
            )
        }
    }
    
    // MARK: - Navigation Logic
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "phonicsSegue",
           let coverVC = segue.destination as? PhonicsCoverViewController {

            let index = phonicsExerciseCycle.currentIndex()
            
            if index < ExerciseType.allCases.count {
                coverVC.chosenExercise = ExerciseType.allCases[index]
            } else {
                coverVC.chosenExercise = ExerciseType.allCases.first
            }
            advancePhonicsExerciseCycle()
        }
    }
    
    func advancePhonicsExerciseCycle() {
        phonicsExerciseCycle.moveToNext()
        ExerciseCycleStore.save(phonicsExerciseCycle, key: phonicsCycleKey)
    }
    
    // MARK: - Actions
    @IBAction func phonicsTapped(_ sender: UITapGestureRecognizer) {
        performSegue(withIdentifier: "phonicsSegue", sender: nil)
    }
    
    @IBAction func readingTapped(_ sender: UITapGestureRecognizer) {
        performSegue(withIdentifier: "readingSegue", sender: nil)
    }

    @IBAction func writingTapped(_ sender: UITapGestureRecognizer) {
        performSegue(withIdentifier: "writingSegue", sender: nil)
    }
    
    @IBAction func ocrTapped(_ sender: UITapGestureRecognizer) {
        performSegue(withIdentifier: "ocrSegue", sender: nil)
    }
    
}



