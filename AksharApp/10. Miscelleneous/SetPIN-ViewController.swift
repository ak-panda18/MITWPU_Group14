//
//  SetPIN-ViewController.swift
//  Screendesigns
//
//  Created by Krish Shrotiya on 13/12/25.
//

import UIKit

// MARK: - SetPINDelegate Protocol
/// Delegate protocol to communicate PIN changes back to the parent view controller
protocol SetPINDelegate: AnyObject {
    /// Called when a PIN is successfully set or changed
    /// - Parameter pin: The 4-digit PIN that was saved
    func didSetPIN(_ pin: String)
}

// MARK: - Set PIN View Controller
/// View controller for setting or changing a 4-digit parental control PIN
class SetPIN_ViewController: UIViewController {

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
    
    /// Button to save the PIN (enabled only when 4 digits are entered)
    @IBOutlet weak var saveButton: UIButton!
    
    // MARK: PIN Indicator Dots
    /// Visual indicators showing PIN entry progress (4 dots total)
    @IBOutlet weak var dotOne: UILabel!
    @IBOutlet weak var dotTwo: UILabel!
    @IBOutlet weak var dotThree: UILabel!
    @IBOutlet weak var dotFour: UILabel!
    
    // MARK: - Properties
    
    // MARK: Delegate
    /// Delegate to notify when PIN is successfully saved
    weak var delegate: SetPINDelegate?
    
    // MARK: State Management
    /// Flag indicating if user is changing an existing PIN or setting a new one
    var isChangingPIN: Bool = false
    
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
        
        // Update title based on whether changing or setting PIN
        if let titleLabel = view.viewWithTag(100) as? UILabel {
            titleLabel.text = isChangingPIN ? "Enter New PIN" : "Enter PIN"
        }
    }
    
    // MARK: - Setup Methods
    
    
    /// Initializes the PIN entry interface with hollow dots and disabled save button
    private func setupInitialState() {
        // Set all dots to hollow initially
        dotOne.text = hollowCircle
        dotTwo.text = hollowCircle
        dotThree.text = hollowCircle
        dotFour.text = hollowCircle
        
        // Disable save button initially
        saveButton.isEnabled = false
        saveButton.alpha = 0.5
    }
    
    // MARK: - IBActions
    
    /// Handles number button taps to build the PIN
    /// - Parameter sender: The number button that was tapped (0-9)
    @IBAction func numberButtonTapped(_ sender: UIButton) {
        // Only allow 4 digits
        guard enteredPIN.count < 4 else { return }
        
        // Get the number from button title
        if let numberText = sender.titleLabel?.text {
            enteredPIN += numberText
            updateDots()
            
            // Enable save button when 4 digits are entered
            if enteredPIN.count == 4 {
                saveButton.isEnabled = true
                saveButton.alpha = 1.0
            }
        }
    }
    
    /// Handles delete button tap to remove the last entered digit
    /// - Parameter sender: The delete button
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        guard !enteredPIN.isEmpty else { return }
        
        enteredPIN.removeLast()
        updateDots()
        
        // Disable save button if less than 4 digits
        if enteredPIN.count < 4 {
            saveButton.isEnabled = false
            saveButton.alpha = 0.5
        }
    }
    
    /// Handles save button tap to store the PIN and dismiss the view
    /// - Parameter sender: The save button
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        guard enteredPIN.count == 4 else { return }
           
           // Save PIN to UserDefaults
           UserDefaults.standard.set(enteredPIN, forKey: "userPIN")
           
           // Notify delegate
           delegate?.didSetPIN(enteredPIN)
           
           // Show appropriate alert based on whether setting or changing PIN
           let alertTitle = isChangingPIN ? "PIN Changed" : "PIN Set"
           let alertMessage = isChangingPIN ? "Your PIN has been successfully changed." : "Your PIN has been successfully set."
           
           let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
           
           alert.addAction(
            
            UIAlertAction(title: "OK", style: .default) { _ in
               // Dismiss ALL modals back to Profile
               if self.isChangingPIN {
                   // We're changing PIN, so we need to dismiss both SetPIN and VerifyPIN
                   self.view.window?.rootViewController?.dismiss(animated: true, completion: nil)
               } else {
                   // First time setting PIN, only one modal to dismiss
                   self.dismiss(animated: true, completion: nil)
               }
           }
        
           )
           
           present(alert, animated: true)
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
}
