//
//  Trophies-ViewController.swift
//  Screendesigns
//
//  Created by Krish Shrotiya on 15/12/25.
//

import UIKit

class Trophies_ViewController: UIViewController {

// Current Trophy level
    @IBOutlet weak var storyExplorerCurrentImage: UIImageView!
    @IBOutlet weak var rhymeRookieCurrentImage: UIImageView!
    @IBOutlet weak var letterTracerCurrentImage: UIImageView!
    @IBOutlet weak var checkpointChampCurrentImage: UIImageView!
    
    //Progress bar
    @IBOutlet weak var storyProgressBar: UIProgressView!
    @IBOutlet weak var rhymingProgressBar: UIProgressView!
    @IBOutlet weak var checkpointProgressBar: UIProgressView!
    @IBOutlet weak var tracerProgressBar: UIProgressView!
    
    //Cards
    @IBOutlet weak var letterTracerCard: UIView!
    @IBOutlet weak var checkpointChampCard: UIView!
    @IBOutlet weak var storyExplorerCard: UIView!
    @IBOutlet weak var rhymingRookieCard: UIView!
    
    //current number progress
    @IBOutlet weak var tracerCurrentNumber: UILabel!
    @IBOutlet weak var storyCurrentNumber: UILabel!
    @IBOutlet weak var rhymingCurrentNumber: UILabel!
    @IBOutlet weak var checkpointCurrentNumber: UILabel!
    
    //goal number progress
    @IBOutlet weak var tracerGoalNumber: UILabel!
    @IBOutlet weak var storyGoalNumber: UILabel!
    @IBOutlet weak var rhymingGoalNumber: UILabel!
    @IBOutlet weak var checkpointGoalNumber: UILabel!
    
    //next trophy level
    @IBOutlet weak var storyExplorerNextImage: UIImageView!
    @IBOutlet weak var rhymeRookieNextImage: UIImageView!
    @IBOutlet weak var letterTracerNextImage: UIImageView!
    @IBOutlet weak var checkpointChampNextImage: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Custom color RGB(231, 199, 110)
        let strokeColor = UIColor(red: 231/255, green: 199/255, blue: 110/255, alpha: 1.0)
        
        // Apply styling to all cards
        styleCard(letterTracerCard, strokeColor: strokeColor)
        styleCard(checkpointChampCard, strokeColor: strokeColor)
        styleCard(rhymingRookieCard, strokeColor: strokeColor)
        styleCard(storyExplorerCard, strokeColor: strokeColor)
    }
    
    func styleCard(_ card: UIView, strokeColor: UIColor) {
        // SHADOW - matching Profile view controller
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.1
        card.layer.shadowOffset = CGSize(width: 0, height: 1)
        card.layer.shadowRadius = 4
        card.layer.masksToBounds = false
        
        // STROKE/BORDER - custom gold color
        card.layer.borderColor = strokeColor.cgColor
        card.layer.borderWidth = 4.0
        
        // Performance optimization - using traitCollection instead of deprecated UIScreen.main
        card.layer.shouldRasterize = true
        card.layer.rasterizationScale = traitCollection.displayScale
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
