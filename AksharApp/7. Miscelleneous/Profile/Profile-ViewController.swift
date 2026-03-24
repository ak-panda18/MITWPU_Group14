
import UIKit
import FirebaseAuth
import UserNotifications
import CoreData
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AksharApp", category: "ProfileViewController")

class Profile_ViewController: UIViewController,
                              EditPersonalInfoDelegate, SetPINDelegate,
                              UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - Injected
    var analyticsStore: AnalyticsStore!
    var checkpointHistoryManager: CheckpointHistoryManager!
    var childManager: ChildManager!
    var profileStore: ProfileStore!

    // MARK: - Outlets: Cards
    @IBOutlet weak var streakCard: UIView!
    @IBOutlet weak var privacyCard: UIView!
    @IBOutlet weak var personalInfoBackground: UIView!
    @IBOutlet weak var remindersCard: UIView!
    @IBOutlet weak var ParentalControlCard: UIView!

    // MARK: - Outlets: Streak
    @IBOutlet weak var mondayStreak: UIView!
    @IBOutlet weak var tuesdayStreak: UIView!
    @IBOutlet weak var wednesdayStreak: UIView!
    @IBOutlet weak var thursdayStreak: UIView!
    @IBOutlet weak var fridayStreak: UIView!
    @IBOutlet weak var saturdayStreak: UIView!
    @IBOutlet weak var sundayStreak: UIView!
    @IBOutlet weak var streakNumber: UILabel!

    // MARK: - Outlets: Header
    @IBOutlet weak var analyticsButton: UIButton!
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var profileName: UILabel!

    // MARK: - Outlets: Personal Info
    @IBOutlet weak var firstName: UILabel!
    @IBOutlet weak var lastName: UILabel!
    @IBOutlet weak var gender: UILabel!
    @IBOutlet weak var age: UILabel!
    @IBOutlet weak var editProfileButton: UIButton!

    // MARK: - Outlets: Reminders
    @IBOutlet weak var mondayReminder: UIButton!
    @IBOutlet weak var tuesdayReminder: UIButton!
    @IBOutlet weak var wednesdayReminder: UIButton!
    @IBOutlet weak var thursdayReminder: UIButton!
    @IBOutlet weak var fridayReminder: UIButton!
    @IBOutlet weak var saturdayReminder: UIButton!
    @IBOutlet weak var sundayReminder: UIButton!
    @IBOutlet weak var reminderSwitch: UISwitch!

    // MARK: - Outlets: Parental
    @IBOutlet weak var setPinButton: UIButton!
    @IBOutlet weak var forgotPINButton: UIButton!

    // MARK: - Outlets: Account
    @IBOutlet weak var deleteAccountButton: UIButton!
    @IBOutlet weak var logOutButton: UIButton!

    // MARK: - Constants
    private let yellowOn = UIColor(red: 255/255, green: 231/255, blue: 131/255, alpha: 1.0)
    private let whiteOff = UIColor.white

    private var dayButtons: [UIButton] {
        [mondayReminder, tuesdayReminder, wednesdayReminder,
         thursdayReminder, fridayReminder, saturdayReminder, sundayReminder]
            .compactMap { $0 }
    }

    private var childUID: String {
        Auth.auth().currentUser?.uid
            ?? childManager.currentChild.id?.uuidString
            ?? "default"
    }

    // MARK: - Lifecycle
    private func verifyDependencies() {
        assert(analyticsStore != nil, "analyticsStore was not injected into \(type(of: self))")
        assert(checkpointHistoryManager != nil, "checkpointHistoryManager was not injected into \(type(of: self))")
        assert(childManager != nil, "childManager was not injected into \(type(of: self))")
        assert(profileStore != nil, "profileStore was not injected into \(type(of: self))")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        verifyDependencies()
        applyCardStyles()
        setupStreakViews()
        setupProfileImageTap()
        loadProfileData()
        updateStreakCard()
        loadReminderState()
        checkPINStatus()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    // MARK: - Profile Data
    private func loadProfileData() {
        let child        = childManager.currentChild
        let firebaseName = Auth.auth().currentUser?.displayName

        let resolvedFirstName: String
        let resolvedLastName: String

        if let saved = child.firstName?.nilIfEmpty {
            resolvedFirstName = saved
            resolvedLastName  = child.lastName ?? ""
        } else {
            let fullName  = child.name?.nilIfEmpty ?? firebaseName ?? ""
            let parts     = fullName.split(separator: " ", maxSplits: 1).map(String.init)
            resolvedFirstName = parts.first ?? fullName
            resolvedLastName  = parts.count > 1 ? parts[1] : (child.lastName ?? "")

            if !resolvedFirstName.isEmpty {
                child.firstName = resolvedFirstName
                child.lastName  = resolvedLastName
                childManager.saveProfileData()
            }
        }

        let displayName = resolvedFirstName.nilIfEmpty ?? firebaseName ?? "Profile"

        logger.debug("ProfileVC: loading profile for child id=\(child.id?.uuidString ?? "nil") name=\(child.name ?? "nil")")

        profileName.text = displayName
        firstName.text   = resolvedFirstName
        lastName.text    = resolvedLastName
        gender.text      = child.gender ?? ""
        age.text         = child.age == 0 ? "" : String(child.age)

        profileImage.layer.cornerRadius  = profileImage.frame.width / 2
        profileImage.layer.masksToBounds = true
        profileImage.contentMode         = .scaleAspectFill

        if let data = child.profileImageData, let img = UIImage(data: data) {
            profileImage.image = img
            removeCameraOverlay()
            showPencilButton(true)
        } else {
            profileImage.image           = nil
            profileImage.backgroundColor = UIColor.systemGray5
            addCameraOverlay()
            showPencilButton(false)
        }
    }

    // MARK: - Streak Card
    private func updateStreakCard() {
        let child    = childManager.currentChild
        let visitKey = "visitDates_\(child.id?.uuidString ?? "default")"
        let today    = Calendar.current.startOfDay(for: Date())
        var visits   = loadDates(forKey: visitKey)

        if !visits.contains(today) {
            visits.append(today)
            saveDates(visits, forKey: visitKey)
        }

        var streak = 0, check = today
        while visits.contains(check) {
            streak += 1
            check   = Calendar.current.date(byAdding: .day, value: -1, to: check)!
        }
        streakNumber.text = "\(streak)"

        let dayViews = [mondayStreak, tuesdayStreak, wednesdayStreak,
                        thursdayStreak, fridayStreak, saturdayStreak, sundayStreak]
        var comps     = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        comps.weekday = 2
        guard let monday = Calendar.current.date(from: comps) else { return }

        for (i, view) in dayViews.enumerated() {
            guard let view else { continue }
            let day      = Calendar.current.date(byAdding: .day, value: i, to: monday)!
            let isToday  = Calendar.current.isDate(day, inSameDayAs: today)
            let isFuture = day > today
            let visited  = visits.contains(Calendar.current.startOfDay(for: day))
            let label    = view.subviews.first(where: { $0 is UILabel }) as? UILabel

            if visited && !isFuture {
                view.backgroundColor   = UIColor(red: 0.25, green: 0.80, blue: 0.35, alpha: 1.0)
                view.layer.borderColor = UIColor.clear.cgColor
                label?.textColor       = .white
            } else if isToday {
                view.backgroundColor   = yellowOn
                view.layer.borderColor = UIColor(red: 200/255, green: 160/255, blue: 0, alpha: 1).cgColor
                label?.textColor       = .black
            } else {
                view.backgroundColor   = .white
                view.layer.borderColor = UIColor.systemGray4.cgColor
                label?.textColor       = .systemGray
            }
        }
    }

    private func loadDates(forKey key: String) -> [Date] {
        guard let data  = UserDefaults.standard.data(forKey: key),
              let dates = try? JSONDecoder().decode([Date].self, from: data)
        else { return [] }
        return dates
    }

    private func saveDates(_ dates: [Date], forKey key: String) {
        if let data = try? JSONEncoder().encode(dates) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Reminders
    private func loadReminderState() {
        let uid     = childUID
        let enabled = profileStore.isReminderEnabled(uid: uid)
        let days    = profileStore.reminderDays(uid: uid)

        reminderSwitch.isOn = enabled
        setDayButtonsInteractive(enabled)

        for (i, btn) in dayButtons.enumerated() {
            btn.tintColor           = .clear
            btn.layer.cornerRadius  = btn.bounds.height / 2
            btn.layer.masksToBounds = true
            btn.setTitleColor(.black, for: .normal)
            btn.backgroundColor = days[i] ? yellowOn : whiteOff
        }
    }

    @IBAction func toggleReminderDay(_ sender: UIButton) {
        guard let i = dayButtons.firstIndex(of: sender) else { return }
        var days = profileStore.reminderDays(uid: childUID)
        days[i]  = !days[i]
        profileStore.setReminderDays(days, uid: childUID)
        sender.backgroundColor = days[i] ? yellowOn : whiteOff
        profileStore.scheduleNotifications(uid: childUID)
    }

    @IBAction func reminderSwitchToggled(_ sender: UISwitch) {
        profileStore.setReminderEnabled(sender.isOn, uid: childUID)
        setDayButtonsInteractive(sender.isOn)
        if sender.isOn {
            profileStore.scheduleNotifications(uid: childUID)
        } else {
            profileStore.cancelAllNotifications()
        }
    }

    @IBAction func setReminderTimeTapped(_ sender: UIButton) {
        let alert  = UIAlertController(title: "Reminder Time", message: "\n\n\n\n\n\n", preferredStyle: .alert)
        let picker = UIDatePicker()
        picker.datePickerMode          = .time
        picker.preferredDatePickerStyle = .wheels
        picker.translatesAutoresizingMaskIntoConstraints = false

        var comps    = DateComponents()
        comps.hour   = profileStore.reminderHour(uid: childUID)
        comps.minute = profileStore.reminderMinute(uid: childUID)
        if let date  = Calendar.current.date(from: comps) { picker.date = date }

        alert.view.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            picker.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 50),
        ])
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self else { return }
            let c = Calendar.current.dateComponents([.hour, .minute], from: picker.date)
            self.profileStore.setReminderTime(hour: c.hour ?? 17, minute: c.minute ?? 0, uid: self.childUID)
            self.profileStore.scheduleNotifications(uid: self.childUID)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func setDayButtonsInteractive(_ on: Bool) {
        dayButtons.forEach {
            $0.isEnabled = on
            $0.alpha     = on ? 1.0 : 0.5
        }
    }

    // MARK: - Profile Image
    private func setupProfileImageTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(profileImageTapped))
        profileImage.isUserInteractionEnabled = true
        profileImage.addGestureRecognizer(tap)
        setupPencilButton()
    }

    private func setupPencilButton() {
        guard let parent = profileImage.superview else { return }
        guard parent.viewWithTag(9002) == nil else { return }

        let size: CGFloat = 28
        let pencilButton  = UIButton(type: .system)
        pencilButton.tag  = 9002
        pencilButton.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        pencilButton.setImage(UIImage(systemName: "pencil", withConfiguration: config), for: .normal)
        pencilButton.tintColor        = UIColor(red: 0.38, green: 0.22, blue: 0.09, alpha: 1.0) // brown
        pencilButton.backgroundColor  = UIColor(red: 1.0, green: 0.87, blue: 0.51, alpha: 1.0)  // yellow
        pencilButton.layer.cornerRadius  = size / 2
        pencilButton.layer.masksToBounds = false
        pencilButton.layer.shadowColor   = UIColor.black.cgColor
        pencilButton.layer.shadowOpacity = 0.18
        pencilButton.layer.shadowOffset  = CGSize(width: 0, height: 1)
        pencilButton.layer.shadowRadius  = 3
        pencilButton.isHidden = true

        pencilButton.addTarget(self, action: #selector(profileImageTapped), for: .touchUpInside)
        parent.addSubview(pencilButton)

        NSLayoutConstraint.activate([
            pencilButton.widthAnchor.constraint(equalToConstant: size),
            pencilButton.heightAnchor.constraint(equalToConstant: size),
            pencilButton.trailingAnchor.constraint(equalTo: profileImage.trailingAnchor, constant: 2),
            pencilButton.bottomAnchor.constraint(equalTo: profileImage.bottomAnchor, constant: 2)
        ])
    }

    private func showPencilButton(_ visible: Bool) {
        profileImage.superview?.viewWithTag(9002)?.isHidden = !visible
    }

    @objc private func profileImageTapped() {
        let alert = UIAlertController(title: "Profile Photo", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Take Photo",          style: .default) { [weak self] _ in self?.openPicker(.camera) })
        alert.addAction(UIAlertAction(title: "Choose from Library", style: .default) { [weak self] _ in self?.openPicker(.photoLibrary) })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = profileImage
            pop.sourceRect = profileImage.bounds
        }
        present(alert, animated: true)
    }

    private func openPicker(_ source: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(source) else { return }
        let p = UIImagePickerController()
        p.sourceType = source; p.allowsEditing = true; p.delegate = self
        present(p, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let img = (info[.editedImage] ?? info[.originalImage]) as? UIImage else { return }
        profileImage.image = img
        removeCameraOverlay()
        showPencilButton(true)
        NotificationCenter.default.post(name: .profileImageDidChange, object: img)
        let child = childManager.currentChild
        child.profileImageData = img.jpegData(compressionQuality: 0.7)
        childManager.saveProfileData()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    private func addCameraOverlay() {
        guard profileImage.viewWithTag(9001) == nil else { return }
        let overlay = UIView(frame: profileImage.bounds)
        overlay.tag = 9001; overlay.isUserInteractionEnabled = false

        let cam = UIImageView(image: UIImage(systemName: "camera.fill"))
        cam.tintColor = .white; cam.contentMode = .scaleAspectFit
        cam.translatesAutoresizingMaskIntoConstraints = false

        let lbl = UILabel()
        lbl.text = "Add Photo"; lbl.textColor = .white
        lbl.font = .systemFont(ofSize: 12, weight: .medium)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [cam, lbl])
        stack.axis = .vertical; stack.spacing = 4; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            cam.widthAnchor.constraint(equalToConstant: 32),
            cam.heightAnchor.constraint(equalToConstant: 32),
        ])
        profileImage.addSubview(overlay)
    }

    private func removeCameraOverlay() {
        profileImage.viewWithTag(9001)?.removeFromSuperview()
        profileImage.backgroundColor = .clear
    }

    // MARK: - Navigation
    @IBAction func goToAnalyticsTapped(_ sender: UIButton) {
        if UserDefaults.standard.string(forKey: pinKey) != nil {
            pendingAnalyticsAccess = true
            performSegue(withIdentifier: "showVerifyPIN", sender: self)
        } else {
            pushAnalyticsVC()
        }
    }

    var pendingAnalyticsAccess = false

    func analyticsUnlocked() {
        pendingAnalyticsAccess = false
        pushAnalyticsVC()
    }

    private func pushAnalyticsVC() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "AnalyticsViewController")
                as? AnalyticsViewController else { return }
        vc.analyticsStore           = analyticsStore
        vc.checkpointHistoryManager = checkpointHistoryManager
        navigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func logOutTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Log Out",
            message: "Are you sure you want to log out?",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Log Out", style: .destructive) { [weak self] _ in
            guard let self else { return }
            do {
                try Auth.auth().signOut()
                guard let sd = self.view.window?.windowScene?.delegate as? SceneDelegate else { return }
                sd.showAuthAfterSignOut()
            } catch {
                logger.error("ProfileVC: sign out failed – \(error)")
            }
        })
        present(alert, animated: true)
    }

    @IBAction func deleteAccountTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Delete Account",
            message: "This will permanently delete your account and all progress data. This cannot be undone.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performAccountDeletion()
        })
        present(alert, animated: true)
    }

    private func performAccountDeletion() {
        guard let user = Auth.auth().currentUser else { return }

        let context = childManager.currentChild.managedObjectContext
        context?.delete(childManager.currentChild)
        try? context?.save()

        user.delete { [weak self] error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let error {
                    let nsError = error as NSError
                    if nsError.code == 17014 {
                        self.showAlert("Please sign out and sign back in, then try deleting again.")
                    } else {
                        self.showAlert("Failed to delete account. Please try again.")
                    }
                    return
                }
                guard let sd = self.view.window?.windowScene?.delegate as? SceneDelegate else { return }
                sd.showAuthAfterSignOut()
            }
        }
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @IBAction func homeTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Parental Controls
    @IBAction func setPinButtonTapped(_ sender: UIButton) {
        if UserDefaults.standard.string(forKey: pinKey) != nil {
            pendingAnalyticsAccess = false
            performSegue(withIdentifier: "showVerifyPIN", sender: self)
        } else {
            performSegue(withIdentifier: "showSetPIN", sender: self)
        }
    }

    @IBAction func forgotPINButtonTapped(_ sender: UIButton) {
        guard let email = Auth.auth().currentUser?.email else {
            showAlert("No email address found for this account.")
            return
        }
        let alert = UIAlertController(
            title: "Forgot PIN",
            message: "A reset link will be sent to \(email). Your current PIN will be cleared so you can set a new one.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send Email", style: .default) { [weak self] _ in
            guard let self else { return }
            Auth.auth().sendPasswordReset(withEmail: email) { _ in }
            UserDefaults.standard.removeObject(forKey: self.pinKey)
            self.checkPINStatus()
            let confirm = UIAlertController(
                title: "Email Sent",
                message: "Check your inbox. Your PIN has been cleared — tap Set PIN to create a new one.",
                preferredStyle: .alert)
            confirm.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(confirm, animated: true)
        })
        present(alert, animated: true)
    }

    private var pinKey: String { "userPIN_\(childUID)" }

    private func checkPINStatus() {
        setPinButton.isEnabled = true
        setPinButton.alpha     = 1.0
        let hasPIN = UserDefaults.standard.string(forKey: pinKey) != nil
        setPinButton.setTitle(hasPIN ? "Change PIN" : "Set PIN", for: .normal)
        forgotPINButton?.isHidden = !hasPIN
    }

    // MARK: - Card UI Setup
    private func applyCardStyles() {
        [streakCard, privacyCard, personalInfoBackground, remindersCard, ParentalControlCard]
            .compactMap { $0 }.forEach { v in
                v.layer.shadowColor        = UIColor.black.cgColor
                v.layer.shadowOpacity      = 0.1
                v.layer.shadowOffset       = CGSize(width: 0, height: 1)
                v.layer.shadowRadius       = 4
                v.layer.masksToBounds      = false
                v.layer.borderColor        = UIColor.black.withAlphaComponent(0.1).cgColor
                v.layer.borderWidth        = 1.0
                v.layer.shouldRasterize    = true
                v.layer.rasterizationScale = traitCollection.displayScale
            }
    }

    private func setupStreakViews() {
        [mondayStreak, tuesdayStreak, wednesdayStreak, thursdayStreak,
         fridayStreak, saturdayStreak, sundayStreak].compactMap { $0 }.forEach {
            $0.layer.cornerRadius  = $0.frame.height / 2
            $0.layer.masksToBounds = true
            $0.layer.borderWidth   = 1.5
        }
    }

    // MARK: - Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editProfile" {
            let dest   = segue.destination
            let editVC = (dest as? UINavigationController)?.topViewController as? EditPersonalInfo_ViewController
                      ?? dest as? EditPersonalInfo_ViewController

            guard let editVC else { return }
            editVC.delegate         = self
            editVC.childManager     = childManager
            let child               = childManager.currentChild
            editVC.currentFirstName = child.firstName?.nilIfEmpty ?? child.name?.nilIfEmpty ?? ""
            editVC.currentLastName  = child.lastName  ?? ""
            editVC.currentAge       = child.age == 0 ? nil : child.age
            editVC.currentGender    = child.gender    ?? ""

        } else if segue.identifier == "showSetPIN",
                  let vc = segue.destination as? SetPIN_ViewController {
            vc.delegate      = self
            vc.isChangingPIN = false
            vc.pinStorageKey = pinKey

        } else if segue.identifier == "showVerifyPIN",
                  let vc = segue.destination as? VerifyPIN_ViewController {
            vc.pinStorageKey   = pinKey
            vc.profileVC       = self
            vc.isAnalyticsGate = pendingAnalyticsAccess
        }
    }

    // MARK: - Delegates
    func didUpdatePersonalInfo(firstName: String, lastName: String, age: Int16, gender: String) {
        self.firstName.text   = firstName
        self.lastName.text    = lastName
        self.age.text         = age == 0 ? "" : String(age)
        self.gender.text      = gender
        self.profileName.text = firstName.nilIfEmpty ?? self.profileName.text
    }

    func didSetPIN(_ pin: String) {
        checkPINStatus()
    }
}

// MARK: - Helpers
private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension Notification.Name {
    static let profileImageDidChange = Notification.Name("profileImageDidChange")
}
