import UIKit

private enum StickerTag {
    static let bottomSlide = 999_999
    static let topRight    = 888_888
}

extension UIViewController {

    func showStickerFromBottom(
        assetName: String,
        displayDuration: TimeInterval = 1.0
    ) {
        guard view.viewWithTag(StickerTag.bottomSlide) == nil else { return }

        let stickerSize: CGFloat = 400
        let stickerView = UIImageView(image: UIImage(named: assetName))
        stickerView.tag         = StickerTag.bottomSlide
        stickerView.contentMode = .scaleAspectFit

        let parent = view!
        stickerView.frame = CGRect(
            x: parent.bounds.midX - stickerSize / 2,
            y: parent.bounds.maxY + stickerSize,
            width: stickerSize,
            height: stickerSize
        )
        parent.addSubview(stickerView)

        UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseOut], animations: {
            stickerView.center.y = parent.bounds.midY
        }, completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
                UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseIn], animations: {
                    stickerView.frame.origin.y = parent.bounds.maxY + stickerSize
                }, completion: { _ in
                    stickerView.removeFromSuperview()
                })
            }
        })
    }

    func showStickerAtTopRight(assetName: String, horizontalOffset: CGFloat = 30) {
        removeSticker()

        let parent       = view!
        let stickerSize: CGFloat = 250
        let padding:     CGFloat = 30

        let stickerView = UIImageView(image: UIImage(named: assetName))
        stickerView.tag         = StickerTag.topRight
        stickerView.contentMode = .scaleAspectFit

        let safeAreaTop = parent.safeAreaInsets.top
        let targetX     = parent.bounds.width - stickerSize - horizontalOffset
        let targetY     = safeAreaTop + padding + 40

        stickerView.frame     = CGRect(x: targetX, y: targetY, width: stickerSize, height: stickerSize)
        stickerView.transform = CGAffineTransform(scaleX: 3.0, y: 3.0).rotated(by: -0.5)
        stickerView.alpha     = 0

        parent.addSubview(stickerView)

        UIView.animate(
            withDuration: 0.5, delay: 0,
            usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8,
            options: [.allowUserInteraction, .curveEaseOut],
            animations: {
                stickerView.transform = .identity
                stickerView.alpha     = 1
            },
            completion: nil
        )
    }

    func removeSticker() {
        guard let sticker = view.viewWithTag(StickerTag.topRight) else { return }
        UIView.animate(withDuration: 0.2, animations: {
            sticker.alpha     = 0
            sticker.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        }) { _ in
            sticker.removeFromSuperview()
        }
    }
}
