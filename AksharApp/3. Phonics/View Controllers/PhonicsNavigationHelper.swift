import UIKit

extension UIViewController {
    func goBackToPhonicsCover() {
        guard let nav = navigationController else { return }

        for vc in nav.viewControllers {
            if vc is PhonicsCoverViewController {
                nav.popToViewController(vc, animated: false)
                return
            }
        }
    }
    func goHomeFromPhonics() {
        navigationController?.popToRootViewController(animated: true)
    }
}
