//
// Profile-ViewController.swift
// Screendesigns
//
// Created by Krish Shrotiya on 09/12/25.
//

import UIKit

// MARK: - Profile View Controller
class Profile_ViewController: UIViewController, EditPersonalInfoDelegate, SetPINDelegate {
    
    // MARK: Background Card Views
    @IBOutlet weak var streakCard: UIView!
    @IBOutlet weak var privacyCard: UIView!
    @IBOutlet weak var personalInfoBackground: UIView!
    @IBOutlet weak var remindersCard: UIView!
    @IBOutlet weak var ParentalControlCard: UIView!
    
    // MARK: Streak Views
    @IBOutlet weak var mondayStreak: UIView!
    @IBOutlet weak var tuesdayStreak: UIView!
    @IBOutlet weak var wednesdayStreak: UIView!
    @IBOutlet weak var thursdayStreak: UIView!
    @IBOutlet weak var fridayStreak: UIView!
    @IBOutlet weak var saturdayStreak: UIView!
    @IBOutlet weak var sundayStreak: UIView!
    
    // MARK: Streak Information
    @IBOutlet weak var streakNumber: UILabel!
    
    // MARK: Navigation Buttons
    @IBOutlet weak var analyticsButton: UIButton!
    
    // MARK: Profile Header
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var profileName: UILabel!
    
    // MARK: Personal Information
    @IBOutlet weak var firstName: UILabel!
    @IBOutlet weak var lastName: UILabel!
    @IBOutlet weak var gender: UILabel!
    @IBOutlet weak var age: UILabel!
    
    @IBOutlet weak var editProfileButton: UIButton!
    
    // MARK: Reminder Controls
    @IBOutlet weak var mondayReminder: UIButton!
    @IBOutlet weak var tuesdayReminder: UIButton!
    @IBOutlet weak var wednesdayReminder: UIButton!
    @IBOutlet weak var thursdayReminder: UIButton!
    @IBOutlet weak var fridayReminder: UIButton!
    @IBOutlet weak var saturdayReminder: UIButton!
    @IBOutlet weak var sundayReminder: UIButton!
    
    @IBOutlet weak var reminderSwitch: UISwitch!
    
    // MARK: Parental Controls
    @IBOutlet weak var setPinButton: UIButton!
    
    @IBOutlet weak var forgotPINButton: UIButton!
    
    // MARK: Account Management
    @IBOutlet weak var deleteAccountButton: UIButton!
    @IBOutlet weak var logOutButton: UIButton!
    
    
    // MARK: Reminder State Management
    let yellowReminderColor = UIColor(red: 255/255, green: 231/255, blue: 131/255, alpha: 1.0)
    
    let whiteReminderColor = UIColor.white
    
    var reminderDays: [UIButton: Bool] = [:]
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UserDefaults.standard.removeObject(forKey: "userPIN")
        
        setupStreakViews()
        applyCardStyleToBackgrounds()
        
        let attendanceData: [UIView: Bool?] = [
            mondayStreak: true, tuesdayStreak: false, wednesdayStreak: true,
            thursdayStreak: true, fridayStreak: false, saturdayStreak: nil, sundayStreak: nil
        ]
        
        applyStreakStatus(data: attendanceData)
        setupReminderButtons()
        
        checkPINStatus()
    }
    
    // MARK: - UI Setup Methods
    func applyCardStyleToBackgrounds() {
        let backgroundViews = [streakCard, privacyCard, personalInfoBackground, remindersCard, ParentalControlCard].compactMap { $0 }
        
        for backgroundView in backgroundViews {
            backgroundView.layer.shadowColor = UIColor.black.cgColor
            backgroundView.layer.shadowOpacity = 0.1
            backgroundView.layer.shadowOffset = CGSize(width: 0, height: 1)
            backgroundView.layer.shadowRadius = 4
            backgroundView.layer.masksToBounds = false

            backgroundView.layer.borderColor = UIColor.black.withAlphaComponent(0.1).cgColor
            backgroundView.layer.borderWidth = 1.0
            
            backgroundView.layer.shouldRasterize = true
            backgroundView.layer.rasterizationScale = traitCollection.displayScale
        }
    }
    
    // MARK: - Streak Management
    func setupStreakViews() {
        let allStreaks = [mondayStreak, tuesdayStreak, wednesdayStreak, thursdayStreak, fridayStreak, saturdayStreak, sundayStreak].compactMap { $0 }
        
        for streakView in allStreaks {
            streakView.layer.cornerRadius = streakView.frame.height / 2
            streakView.layer.masksToBounds = true
            streakView.layer.borderWidth = 1.5
        }
    }
    
    func styleStreakView(view: UIView, attended: Bool?) {
        guard let dayLabel = view.subviews.first(where: { $0 is UILabel }) as? UILabel else { return }
        
        let attendedColor = UIColor(red: 0.25, green: 0.80, blue: 0.35, alpha: 1.0)
        let skippedColor = UIColor(red: 1.0, green: 0.30, blue: 0.30, alpha: 1.0)
        let defaultColor = UIColor.systemGray
        
        if let attended = attended {
            if attended {
                view.backgroundColor = attendedColor
                dayLabel.textColor = UIColor.white
                view.layer.borderColor = UIColor.clear.cgColor
            } else {
                view.backgroundColor = UIColor.white
                dayLabel.textColor = skippedColor
                view.layer.borderColor = skippedColor.cgColor
            }
        } else {
            view.backgroundColor = UIColor.white
            dayLabel.textColor = defaultColor
            view.layer.borderColor = defaultColor.cgColor
        }
    }
    
    func applyStreakStatus(data: [UIView: Bool?]) {
        for (view, attended) in data {
            styleStreakView(view: view, attended: attended)
        }
    }
    
    // MARK: - Reminder Management
    func setupReminderButtons() {
        let reminderButtons = [mondayReminder, tuesdayReminder, wednesdayReminder, thursdayReminder, fridayReminder, saturdayReminder, sundayReminder].compactMap { $0 }
        
        for button in reminderButtons {
            button.tintColor = .clear
            button.backgroundColor = yellowReminderColor
            button.layer.cornerRadius = button.frame.height / 2
            button.layer.masksToBounds = true
            reminderDays[button] = true
            button.setTitleColor(UIColor.black, for: .normal)
        }
    }
    
    func updateReminderButtonState(isEnabled: Bool) {
        let reminderButtons = [mondayReminder, tuesdayReminder, wednesdayReminder, thursdayReminder, fridayReminder, saturdayReminder, sundayReminder].compactMap { $0 }
        
        for button in reminderButtons {
            button.isEnabled = isEnabled
            button.alpha = isEnabled ? 1.0 : 0.4
        }
    }
    
    // MARK: Reminder Actions
    @IBAction func toggleReminderDay(_ sender: UIButton) {
        let currentState = reminderDays[sender] ?? true
        let newState = !currentState
        
        if newState {
            sender.backgroundColor = yellowReminderColor
            sender.setTitleColor(UIColor.black, for: .normal)
        } else {
            sender.backgroundColor = whiteReminderColor
            sender.setTitleColor(UIColor.black, for: .normal)
        }
        
        reminderDays[sender] = newState
    }
    
    @IBAction func reminderSwitchToggled(_ sender: UISwitch) {
        updateReminderButtonState(isEnabled: sender.isOn)
    }
    
    // MARK: Parental Control Actions
    @IBAction func setPinButtonTapped(_ sender: UIButton) {
        if UserDefaults.standard.string(forKey: "userPIN") != nil {
            performSegue(withIdentifier: "showVerifyPIN", sender: self)
        } else {
            performSegue(withIdentifier: "showSetPIN", sender: self)
        }
    }
    
    @IBAction func forgotPINButtonTapped(_ sender: UIButton) {
        
        let alert = UIAlertController(
               title: "Reset PIN Request",
               message: "A PIN reset link has been sent to your registered email address. Please check your inbox.",
               preferredStyle: .alert
           )
           
           alert.addAction(UIAlertAction(title: "OK", style: .default))
           
           present(alert, animated: true)
    }
    
    // MARK: - PIN Management
    func checkPINStatus() {
        if UserDefaults.standard.string(forKey: "userPIN") != nil {
            setPinButton.setTitle("Change PIN", for: .normal)
        } else {
            setPinButton.setTitle("Set PIN", for: .normal)
        }
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("Prepare for segue called")
        print("Segue identifier: \(segue.identifier ?? "no identifier")")
        
        if segue.identifier == "editProfile" {
            print("Edit profile segue matched")
            if let navController = segue.destination as? UINavigationController {
                print("Navigation controller found")
                if let editVC = navController.topViewController as? EditPersonalInfo_ViewController {
                    print("EditPersonalInfo_ViewController found")
                    editVC.delegate = self
                    editVC.currentFirstName = firstName.text
                    editVC.currentLastName = lastName.text
                    editVC.currentAge = age.text
                    editVC.currentGender = gender.text
                } else {
                    print("Could not cast to EditPersonalInfo_ViewController")
                }
            } else {
                print("Could not cast to UINavigationController")
            }
        } else if segue.identifier == "showSetPIN" {
            print("Set PIN segue matched")
            if let setPINVC = segue.destination as? SetPIN_ViewController {
                setPINVC.delegate = self
                setPINVC.isChangingPIN = false
                print("SetPIN_ViewController delegate set")
            }
        } else if segue.identifier == "showVerifyPIN" {
            print("Verify PIN segue matched")
        } else {
            print("Segue identifier did not match")
        }
    }
    
    // MARK: SetPINDelegate
    func didSetPIN(_ pin: String) {
        print("PIN saved successfully: \(pin)")
        checkPINStatus()
    }
    
    // MARK: EditPersonalInfoDelegate
    func didUpdatePersonalInfo(firstName: String, lastName: String, age: String, gender: String) {
        print("Delegate method called!")
        print("Updating with - First: \(firstName), Last: \(lastName), Age: \(age), Gender: \(gender)")
        
        self.firstName.text = firstName
        self.lastName.text = lastName
        self.age.text = age
        self.gender.text = gender
        self.profileName.text = firstName
    }
}
