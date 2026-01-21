import UIKit

class CustomAlertViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var parentView: UIView!
    @IBOutlet weak var rewardImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
    // MARK: - Properties
    var alertTitle: String?
    var alertMessage: String?
    var buttonText: String?
    var alertImage: UIImage?
    var onDismiss: (() -> Void)?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        populateData()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black.withAlphaComponent(0.4)
        
        parentView.backgroundColor = .systemBackground
        parentView.layer.cornerRadius = 25
        parentView.layer.borderWidth = 5
        parentView.layer.borderColor = UIColor.systemYellow.cgColor
        
        parentView.layer.shadowColor = UIColor.black.cgColor
        parentView.layer.shadowOpacity = 0.2
        parentView.layer.shadowOffset = CGSize(width: 0, height: 4)
        parentView.layer.shadowRadius = 10
        
        actionButton.layer.cornerRadius = 15
        actionButton.backgroundColor = .systemYellow
        actionButton.titleLabel?.font = .systemFont(ofSize: 25, weight: .bold)
        
        titleLabel.font = .systemFont(ofSize: 32, weight: .medium).rounded()
        subtitleLabel.font = UIFont(name: "SF Pro Rounded", size: 28)
    }
    
    private func populateData() {
        titleLabel.text = alertTitle
        subtitleLabel.text = alertMessage
        actionButton.setTitle(buttonText, for: .normal)
        
        rewardImageView.image = alertImage
        rewardImageView.isHidden = (alertImage == nil)
    }

    // MARK: - Actions
    @IBAction func actionButtonTapped(_ sender: UIButton) {
        dismiss(animated: false) { [weak self] in
            self?.onDismiss?()
        }
    }
}

// MARK: - Helpers
private extension UIFont {
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
