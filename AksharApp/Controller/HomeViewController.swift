//
//  HomeViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class HomeViewController: UIViewController {

    @IBOutlet weak var ocrView: UIView!
    @IBOutlet weak var phonicsView: UIView!
    @IBOutlet weak var writingView: UIView!
    @IBOutlet weak var readingView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        readingView.layer.cornerRadius = 25
        readingView.layer.borderColor = UIColor.systemBrown.cgColor
        readingView.layer.borderWidth = 2.0
        writingView.layer.cornerRadius = 25
        writingView.layer.borderColor = UIColor.systemBrown.cgColor
        writingView.layer.borderWidth = 2.0
        phonicsView.layer.cornerRadius = 25
        phonicsView.layer.borderColor = UIColor.systemBrown.cgColor
        phonicsView.layer.borderWidth = 2.0
        ocrView.layer.cornerRadius = 25
        ocrView.layer.borderColor = UIColor.systemBrown.cgColor
        ocrView.layer.borderWidth = 2.0
    
    
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "phonicsSegue",
           let coverVC = segue.destination as? PhonicsCoverViewController {

            coverVC.chosenExercise = ExerciseType.allCases.randomElement()
        }
    }
    
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


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
