//
//  SetPIN-ViewController.swift
//  Screendesigns
//
//  Created by Krish Shrotiya on 13/12/25.
//

import UIKit

protocol SetPINDelegate: AnyObject {
    func didSetPIN(_ pin: String)
}

class SetPIN_ViewController: UIViewController {

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
    
    // MARK: Action Buttons
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var dotOne: UILabel!
    @IBOutlet weak var dotTwo: UILabel!
    @IBOutlet weak var dotThree: UILabel!
    @IBOutlet weak var dotFour: UILabel!
    
    // MARK: - Properties
    
    weak var delegate: SetPINDelegate?
    var isChangingPIN: Bool = false
    private var enteredPIN: String = ""
    private let hollowCircle = "○"
    private let filledCircle = "●"

    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupInitialState()
        if let titleLabel = view.viewWithTag(100) as? UILabel {
            titleLabel.text = isChangingPIN ? "Enter New PIN" : "Enter PIN"
        }
    }
    
    // MARK: - Setup Methods
    private func setupInitialState() {
        dotOne.text = hollowCircle
        dotTwo.text = hollowCircle
        dotThree.text = hollowCircle
        dotFour.text = hollowCircle
        saveButton.isEnabled = false
        saveButton.alpha = 0.5
    }
    
    // MARK: - IBActions
    @IBAction func numberButtonTapped(_ sender: UIButton) {
        guard enteredPIN.count < 4 else { return }
        if let numberText = sender.titleLabel?.text {
            enteredPIN += numberText
            updateDots()
            
            if enteredPIN.count == 4 {
                saveButton.isEnabled = true
                saveButton.alpha = 1.0
            }
        }
    }
    
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        guard !enteredPIN.isEmpty else { return }
        
        enteredPIN.removeLast()
        updateDots()
        
        if enteredPIN.count < 4 {
            saveButton.isEnabled = false
            saveButton.alpha = 0.5
        }
    }
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        guard enteredPIN.count == 4 else { return }
           
           UserDefaults.standard.set(enteredPIN, forKey: "userPIN")
           
           delegate?.didSetPIN(enteredPIN)
           let alertTitle = isChangingPIN ? "PIN Changed" : "PIN Set"
           let alertMessage = isChangingPIN ? "Your PIN has been successfully changed." : "Your PIN has been successfully set."
           
           let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
           
           alert.addAction(
            
            UIAlertAction(title: "OK", style: .default) { _ in
               if self.isChangingPIN {
                   self.view.window?.rootViewController?.dismiss(animated: true, completion: nil)
               } else {
                   self.dismiss(animated: true, completion: nil)
               }
           }
        
           )
           
           present(alert, animated: true)
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
}
