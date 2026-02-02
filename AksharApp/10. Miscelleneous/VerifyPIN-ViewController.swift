//
//  VerifyPIN-ViewController.swift
//  Screendesigns
//
//  Created by Krish Shrotiya on 13/12/25.
//

import UIKit

// MARK: - Verify PIN View Controller
/// View controller for verifying the current PIN before allowing changes
/// Validates user input against stored PIN and navigates to SetPIN on success
class VerifyPIN_ViewController: UIViewController {

    // MARK: - IBOutlets
    
    // MARK: Number Pad Buttons
    /// Number pad buttons (0-9) for PIN entry
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
    /// Button to delete the last entered digit
    @IBOutlet weak var deleteButton: UIButton!
    
    /// Button to cancel verification and return to previous screen
    @IBOutlet weak var cancelButton: UIButton!
    
    // MARK: PIN Indicator Dots
    /// Visual indicators showing PIN entry progress (4 dots total)
    @IBOutlet weak var dotOne: UILabel!
    @IBOutlet weak var dotTwo: UILabel!
    @IBOutlet weak var dotThree: UILabel!
    @IBOutlet weak var dotFour: UILabel!
    
    // MARK: Error Display
    /// Label to display error messages (e.g., "Incorrect PIN")
    @IBOutlet weak var errorLabel: UILabel!
    
    // MARK: - Properties
    
    // MARK: PIN Entry State
    /// The PIN digits entered by the user (max 4 digits)
    private var enteredPIN: String = ""
    
    // MARK: Visual Constants
    /// Character used to represent an empty/unfilled PIN dot
    private let hollowCircle = "○"
    
    /// Character used to represent a filled PIN dot
    private let filledCircle = "●"

    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupInitialState()
    }
    
    // MARK: - Setup Methods
    
    /// Initializes the PIN verification interface with hollow dots and hidden error label
    private func setupInitialState() {
        // Set all dots to hollow initially
        dotOne.text = hollowCircle
        dotTwo.text = hollowCircle
        dotThree.text = hollowCircle
        dotFour.text = hollowCircle
        
        // Hide error label initially
        errorLabel.isHidden = true
        errorLabel.textColor = .red
    }
    
    // MARK: - IBActions
    
    /// Handles number button taps to build the PIN for verification
    /// Automatically verifies PIN when 4 digits are entered
    /// - Parameter sender: The number button that was tapped (0-9)
    @IBAction func numberButtonTapped(_ sender: UIButton) {
        // Hide error when user starts typing again
        errorLabel.isHidden = true
        
        // Only allow 4 digits
        guard enteredPIN.count < 4 else { return }
        
        // Get the number from button title
        if let numberText = sender.titleLabel?.text {
            enteredPIN += numberText
            updateDots()
            
            // Auto-verify when 4 digits are entered
            if enteredPIN.count == 4 {
                verifyPIN()
            }
        }
    }
    
    /// Handles delete button tap to remove the last entered digit
    /// - Parameter sender: The delete button
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        guard !enteredPIN.isEmpty else { return }
        
        errorLabel.isHidden = true
        enteredPIN.removeLast()
        updateDots()
    }
    
    /// Handles cancel button tap to dismiss the verification screen
    /// - Parameter sender: The cancel button
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Helper Methods
    
    /// Updates the visual dot indicators to reflect the current PIN entry state
    /// Fills dots with solid circles as digits are entered
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
    
    /// Verifies the entered PIN against the stored PIN
    /// On success: navigates to SetPIN screen to enter new PIN
    /// On failure: shows error, shakes dots, and resets entry
    private func verifyPIN() {
        guard let savedPIN = UserDefaults.standard.string(forKey: "userPIN") else {
            showError("No PIN found")
            return
        }
        
        if enteredPIN == savedPIN {
            // PIN is correct, navigate to SetPIN screen
            performSegue(withIdentifier: "verifyToSetPIN", sender: self)
        } else {
            // PIN is incorrect, show error and reset
            showError("Incorrect PIN")
            shakeDots()
            
            // Clear PIN after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.enteredPIN = ""
                self.updateDots()
            }
        }
    }
    
    /// Displays an error message to the user
    /// - Parameter message: The error message to display
    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }
    
    /// Animates the PIN dots with a shake effect to indicate incorrect PIN
    /// Creates a natural shake animation that gradually dampens
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
    
    /// Prepares for segue to SetPIN screen after successful verification
    /// Sets the isChangingPIN flag to true to indicate this is a PIN change operation
    /// - Parameters:
    ///   - segue: The segue being performed
    ///   - sender: The object that triggered the segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "verifyToSetPIN" {
            if let setPINVC = segue.destination as? SetPIN_ViewController {
                setPINVC.isChangingPIN = true
            }
        }
    }
}
