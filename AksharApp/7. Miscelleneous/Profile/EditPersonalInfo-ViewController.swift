import UIKit

protocol EditPersonalInfoDelegate: AnyObject {
    func didUpdatePersonalInfo(firstName: String, lastName: String, age: Int16, gender: String)
}

class EditPersonalInfo_ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    @IBOutlet weak var genderPicker: UIPickerView!
    @IBOutlet weak var ageTextField: UITextField!
    @IBOutlet weak var lastNameTextField: UITextField!
    @IBOutlet weak var firstNameTextField: UITextField!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var cancelButton: UIBarButtonItem!

    // MARK: - Injected
    var childManager: ChildManager?
    weak var delegate: EditPersonalInfoDelegate?

    var currentFirstName: String?
    var currentLastName:  String?
    var currentAge:       Int16?
    var currentGender:    String?

    let genderOptions  = ["Male", "Female", "Other"]
    var selectedGender = "Male"

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        genderPicker.dataSource = self
        genderPicker.delegate   = self

        firstNameTextField.text = currentFirstName
        lastNameTextField.text  = currentLastName
        ageTextField.text       = currentAge.map { String($0) }

        if let g = currentGender, let idx = genderOptions.firstIndex(of: g) {
            genderPicker.selectRow(idx, inComponent: 0, animated: false)
            selectedGender = g
        }
    }

    // MARK: - UIPickerView
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { genderOptions.count }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { genderOptions[row] }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) { selectedGender = genderOptions[row] }

    // MARK: - Actions
    @IBAction func cancelButtonTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }

    @IBAction func saveButtonTapped(_ sender: UIBarButtonItem) {
        let fn     = firstNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ln     = lastNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let agText = ageTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ag     = Int16(agText) ?? 0
        let gn     = selectedGender

        if let child = childManager?.currentChild {
            child.firstName = fn
            child.lastName  = ln
            child.age       = ag
            child.gender    = gn
            if !fn.isEmpty { child.name = fn }
            childManager?.saveProfileData()
        }

        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            self.delegate?.didUpdatePersonalInfo(
                firstName: fn,
                lastName:  ln,
                age:       ag,
                gender:    gn
            )
        }
    }
}
