//
//  WritingPreviewViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit


class WritingPreviewViewController: UIViewController {
    @IBOutlet weak var demoView: UIView!
    @IBOutlet weak var wordImage: UIImageView!
    
    @IBOutlet weak var numberImage: UIImageView!
    @IBOutlet weak var nextWordView: UIView!
    @IBOutlet weak var nextLetterView: UIView!
    @IBOutlet weak var letterImage: UIImageView!
    @IBOutlet weak var numberCardView: UIView!
    @IBOutlet weak var nextNumberView: UIView!
    @IBOutlet weak var wordCardView: UIView!
    @IBOutlet weak var letterCardVIew: UIView!
    
    @objc func openSheet() {
        performSegue(withIdentifier: "sheetSegue", sender: nil)
    }



    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let cardStrokeColor = UIColor(red: 250/255.0, green: 239/255.0, blue: 184/255.0, alpha: 1.0)
        letterCardVIew.layer.borderColor = cardStrokeColor.cgColor
        letterCardVIew.layer.borderWidth = 7
        letterCardVIew.layer.cornerRadius = 25
        wordCardView.layer.borderColor = cardStrokeColor.cgColor
        wordCardView.layer.borderWidth = 7
        wordCardView.layer.cornerRadius = 25
        numberCardView.layer.borderColor = cardStrokeColor.cgColor
        numberCardView.layer.borderWidth = 7
        numberCardView.layer.cornerRadius = 25
        letterImage.layer.cornerRadius = 25
        nextLetterView.layer.cornerRadius = nextLetterView.frame.height/2
        wordImage.layer.cornerRadius = 25
        nextWordView.layer.cornerRadius = nextWordView.frame.height/2
        numberImage.layer.cornerRadius = 25
        nextNumberView.layer.cornerRadius = nextNumberView.frame.height/2
        // Do any additional setup after loading the view.
    
            //let tap = UITapGestureRecognizer(target: self, action: #selector(openSheet))
            //wordCardView.addGestureRecognizer(tap)
            wordCardView.isUserInteractionEnabled = true

    }
    
    @IBAction func backToHomeTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
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
