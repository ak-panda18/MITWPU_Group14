//
//  SignUpViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 09/02/26.
//

import UIKit

class SignUpViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var contentView: UIView!
    @IBOutlet var centreContainerView: UIView!
    @IBOutlet var boardingImageView: UIImageView!
    @IBOutlet var boardingTextView: UITextView!
    @IBOutlet var textFieldStackView: UIStackView!
    @IBOutlet var signUpButton: UIButton!
    @IBOutlet var signInStackView: UIStackView!
    @IBOutlet var signInButton: UIButton!
    @IBOutlet var textFields: [UITextField]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardObservers()

    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        styleTextFieldsAndButton()
    }
    

}
extension SignUpViewController {

    func setupKeyboardObservers() {

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil)
    }

    @objc func keyboardWillShow(_ notification: Notification) {

        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }

        scrollView.contentInset.bottom = frame.height + 20
    }

    @objc func keyboardWillHide(_ notification: Notification) {

        scrollView.contentInset.bottom = 0
    }
    
    private func styleTextFieldsAndButton() {

        textFields.forEach {
            $0.backgroundColor = .white
            $0.layer.borderWidth = 1
            $0.layer.borderColor = UIColor.lightGray.cgColor
            $0.layer.cornerRadius = $0.bounds.height/2
            $0.layer.masksToBounds = true
        }
        
        signUpButton.layer.cornerRadius = signUpButton.bounds.height/2
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

            if let index = textFields.firstIndex(of: textField),
               index < textFields.count - 1 {

                textFields[index + 1].becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }

            return true
    }

}
