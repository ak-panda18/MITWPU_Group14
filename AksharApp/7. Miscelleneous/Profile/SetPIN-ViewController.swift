import UIKit

protocol SetPINDelegate: AnyObject {
    func didSetPIN(_ pin: String)
}

class SetPIN_ViewController: UIViewController {

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
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var dotOne: UILabel!
    @IBOutlet weak var dotTwo: UILabel!
    @IBOutlet weak var dotThree: UILabel!
    @IBOutlet weak var dotFour: UILabel!

    weak var delegate: SetPINDelegate?
    var isChangingPIN: Bool = false
    var pinStorageKey: String = "userPIN"

    private var enteredPIN = ""
    private let hollowCircle = "○"
    private let filledCircle = "●"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupInitialState()
        if let titleLabel = view.viewWithTag(100) as? UILabel {
            titleLabel.text = isChangingPIN ? "Enter New PIN" : "Enter PIN"
        }
    }

    private func setupInitialState() {
        [dotOne, dotTwo, dotThree, dotFour].forEach { $0?.text = hollowCircle }
        saveButton.isEnabled = false
        saveButton.alpha     = 0.5
    }

    @IBAction func numberButtonTapped(_ sender: UIButton) {
        guard enteredPIN.count < 4, let num = sender.titleLabel?.text else { return }
        enteredPIN += num
        updateDots()
        if enteredPIN.count == 4 { saveButton.isEnabled = true; saveButton.alpha = 1.0 }
    }

    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        guard !enteredPIN.isEmpty else { return }
        enteredPIN.removeLast()
        updateDots()
        if enteredPIN.count < 4 { saveButton.isEnabled = false; saveButton.alpha = 0.5 }
    }

    @IBAction func saveButtonTapped(_ sender: UIButton) {
        guard enteredPIN.count == 4 else { return }

        UserDefaults.standard.set(enteredPIN, forKey: pinStorageKey)

        delegate?.didSetPIN(enteredPIN)

        let title   = isChangingPIN ? "PIN Changed" : "PIN Set"
        let message = isChangingPIN ? "Your PIN has been successfully changed." : "Your PIN has been successfully set."
        let alert   = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self else { return }
            if self.isChangingPIN {
                self.view.window?.rootViewController?.dismiss(animated: true)
            } else {
                self.dismiss(animated: true)
            }
        })
        present(alert, animated: true)
    }

    private func updateDots() {
        let dots = [dotOne, dotTwo, dotThree, dotFour]
        for (i, dot) in dots.enumerated() {
            dot?.text = i < enteredPIN.count ? filledCircle : hollowCircle
        }
    }
}
