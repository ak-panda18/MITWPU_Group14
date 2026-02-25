//
//  SignInViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 09/02/26.
//

import UIKit

class SignInViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet var textFields: [UITextField]!
    @IBOutlet var scrollView: UIScrollView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupKeyboardObservers()
        setupTextFields()

    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        styleTextFields()
    }
    

}
// MARK: - Setup
private extension SignInViewController {

    func setupTextFields() {
        textFields.forEach {
            $0.delegate = self
            $0.returnKeyType = .next
        }

        textFields.last?.returnKeyType = .done
    }

    func styleTextFields() {
        textFields.forEach {
            $0.layer.cornerRadius = $0.bounds.height / 2
            $0.layer.borderWidth = 1
            $0.layer.borderColor = UIColor.lightGray.cgColor
            $0.layer.masksToBounds = true
        }
    }
}

// MARK: - Keyboard Handling
extension SignInViewController {

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

        guard let frame =
                notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }

        scrollView.contentInset.bottom = frame.height + 20
        scrollView.verticalScrollIndicatorInsets.bottom = frame.height
    }

    @objc func keyboardWillHide(_ notification: Notification) {

        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
}

// MARK: - TextField Delegate
extension SignInViewController {

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
