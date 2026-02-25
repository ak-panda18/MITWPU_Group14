//
//  VerifyPIN-ViewController.swift
//  Screendesigns
//
//  Created by Krish Shrotiya on 13/12/25.
//

import UIKit

class VerifyPIN_ViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var oneButton: UIButton!
    @IBOutlet weak var twoButton: UIButton!
    @IBOutlet weak var threeButton: UIButton!
    @IBOutlet weak var fourButton: UIButton!
    @IBOutlet weak var fiveButton: UIButton!
    @IBOutlet weak var sixButton: UIButton!
    @IBOutlet weak var sevenButton: UIButton!
    @IBOutlet weak var eightButton: UIButton!
    @IBOutlet weak var nineButton: UIButton!
    @IBOutlet weak var zeroButton: UIButton!
    
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var dotOne: UILabel!
    @IBOutlet weak var dotTwo: UILabel!
    @IBOutlet weak var dotThree: UILabel!
    @IBOutlet weak var dotFour: UILabel!
    @IBOutlet weak var errorLabel: UILabel!
    
    // MARK: - Properties
    private var enteredPIN: String = ""
    private let hollowCircle = "○"
    private let filledCircle = "●"

    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupInitialState()
    }
    
    // MARK: - Setup Methods
    private func setupInitialState() {
        dotOne.text = hollowCircle
        dotTwo.text = hollowCircle
        dotThree.text = hollowCircle
        dotFour.text = hollowCircle
        
        errorLabel.isHidden = true
        errorLabel.textColor = .red
    }
    
    // MARK: - IBActions
    @IBAction func numberButtonTapped(_ sender: UIButton) {
        errorLabel.isHidden = true
        
        guard enteredPIN.count < 4 else { return }
        
        if let numberText = sender.titleLabel?.text {
            enteredPIN += numberText
            updateDots()
            
            if enteredPIN.count == 4 {
                verifyPIN()
            }
        }
    }
    
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        guard !enteredPIN.isEmpty else { return }
        
        errorLabel.isHidden = true
        enteredPIN.removeLast()
        updateDots()
    }
    
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Helper Methods
    private func updateDots() {
        let dots = [dotOne, dotTwo, dotThree, dotFour]
        
        for (index, dot) in dots.enumerated() {
            if index < enteredPIN.count {
                dot?.text = filledCircle
            } else {
                dot?.text = hollowCircle
            }
        }
    }
    
    private func verifyPIN() {
        guard let savedPIN = UserDefaults.standard.string(forKey: "userPIN") else {
            showError("No PIN found")
            return
        }
        
        if enteredPIN == savedPIN {
            performSegue(withIdentifier: "verifyToSetPIN", sender: self)
        } else {
            showError("Incorrect PIN")
            shakeDots()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.enteredPIN = ""
                self.updateDots()
            }
        }
    }
    
    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }
    
    private func shakeDots() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
           animation.timingFunction = CAMediaTimingFunction(name: .linear)
           animation.duration = 0.5
           animation.values = [-12, 12, -8, 8, -4, 4, 0]
           
           dotOne.layer.add(animation, forKey: "shake")
           dotTwo.layer.add(animation, forKey: "shake")
           dotThree.layer.add(animation, forKey: "shake")
           dotFour.layer.add(animation, forKey: "shake")
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "verifyToSetPIN" {
            if let setPINVC = segue.destination as? SetPIN_ViewController {
                setPINVC.isChangingPIN = true
            }
        }
    }
}
