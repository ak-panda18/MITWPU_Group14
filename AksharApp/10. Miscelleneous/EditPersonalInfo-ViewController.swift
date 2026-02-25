import UIKit

// Define protocol
protocol EditPersonalInfoDelegate: AnyObject {
    func didUpdatePersonalInfo(firstName: String, lastName: String, age: String, gender: String)
}

class EditPersonalInfo_ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    @IBOutlet weak var genderPicker: UIPickerView!
    @IBOutlet weak var ageTextField: UITextField!
    @IBOutlet weak var lastNameTextField: UITextField!
    @IBOutlet weak var firstNameTextField: UITextField!
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    
    weak var delegate: EditPersonalInfoDelegate?
    
    var currentFirstName: String?
    var currentLastName: String?
    var currentAge: String?
    var currentGender: String?
    
    let genderOptions = ["Male", "Female", "Other"]
    var selectedGender: String = "Male"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genderPicker.dataSource = self
        genderPicker.delegate = self
        
        firstNameTextField.text = currentFirstName
        lastNameTextField.text = currentLastName
        ageTextField.text = currentAge
        
        if let gender = currentGender, let index = genderOptions.firstIndex(of: gender) {
            genderPicker.selectRow(index, inComponent: 0, animated: false)
            selectedGender = gender
        }
    }
    
    // MARK: - UIPickerView DataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return genderOptions.count
    }
    
    // MARK: - UIPickerView Delegate
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return genderOptions[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedGender = genderOptions[row]
    }
    
    // MARK: - Actions
    
    @IBAction func cancelButtonTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func saveButtonTapped(_ sender: UIBarButtonItem) {
          let updatedFirstName = firstNameTextField.text ?? ""
          let updatedLastName = lastNameTextField.text ?? ""
          let updatedAge = ageTextField.text ?? ""
          let updatedGender = selectedGender
          
          print("Save button tapped")
          print("First Name: \(updatedFirstName)")
          print("Last Name: \(updatedLastName)")
          print("Age: \(updatedAge)")
          print("Gender: \(updatedGender)")
          print("Delegate is nil: \(delegate == nil)")
          
          delegate?.didUpdatePersonalInfo(firstName: updatedFirstName, lastName: updatedLastName, age: updatedAge, gender: updatedGender)
          
          dismiss(animated: true, completion: nil)
    }
}
