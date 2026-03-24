import UIKit

class VerifyPIN_ViewController: UIViewController {

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

    var pinStorageKey: String = "userPIN"
    var isAnalyticsGate: Bool = false
    weak var profileVC: Profile_ViewController?

    private var enteredPIN  = ""
    private let hollowCircle = "○"
    private let filledCircle = "●"

    override func viewDidLoad() {
        super.viewDidLoad()
        [dotOne, dotTwo, dotThree, dotFour].forEach { $0?.text = hollowCircle }
        errorLabel.isHidden   = true
        errorLabel.textColor  = .systemRed
    }

    @IBAction func numberButtonTapped(_ sender: UIButton) {
        errorLabel.isHidden = true
        guard enteredPIN.count < 4, let num = sender.titleLabel?.text else { return }
        enteredPIN += num
        updateDots()
        if enteredPIN.count == 4 { verifyPIN() }
    }

    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        guard !enteredPIN.isEmpty else { return }
        errorLabel.isHidden = true
        enteredPIN.removeLast()
        updateDots()
    }

    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    private func verifyPIN() {
        guard let saved = UserDefaults.standard.string(forKey: pinStorageKey) else {
            showError("No PIN found"); return
        }
        if enteredPIN == saved {
            dismiss(animated: true) { [weak self] in
                guard let self else { return }
                if self.isAnalyticsGate {
                    self.profileVC?.analyticsUnlocked()
                } else {
                    self.profileVC?.performSegue(withIdentifier: "showSetPIN", sender: self.profileVC)
                }
            }
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
        errorLabel.text     = message
        errorLabel.isHidden = false
    }

    private func updateDots() {
        let dots = [dotOne, dotTwo, dotThree, dotFour]
        for (i, dot) in dots.enumerated() {
            dot?.text = i < enteredPIN.count ? filledCircle : hollowCircle
        }
    }

    private func shakeDots() {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.duration = 0.5
        anim.values   = [-12, 12, -8, 8, -4, 4, 0]
        [dotOne, dotTwo, dotThree, dotFour].forEach { $0?.layer.add(anim, forKey: "shake") }
    }


}
