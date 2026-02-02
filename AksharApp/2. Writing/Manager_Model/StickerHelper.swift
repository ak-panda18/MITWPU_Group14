//
//  StickerHelper.swift
//  AksharApp
//
//  Created by Akshita Panda on 17/01/26.
//

import UIKit

extension UIViewController {

    func showStickerFromBottom(
        assetName: String,
        displayDuration: TimeInterval = 1.0
    ) {
        let tag = 999_999
        guard view.viewWithTag(tag) == nil else { return }

        let stickerSize: CGFloat = 400
        let stickerView = UIImageView(image: UIImage(named: assetName))
        stickerView.tag = tag
        stickerView.contentMode = .scaleAspectFit

        let parent = view!

        stickerView.frame = CGRect(
            x: parent.bounds.midX - stickerSize / 2,
            y: parent.bounds.maxY + stickerSize,
            width: stickerSize,
            height: stickerSize
        )

        parent.addSubview(stickerView)

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            options: [.curveEaseOut],
            animations: {
                stickerView.center.y = parent.bounds.midY
            },
            completion: { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
                    UIView.animate(
                        withDuration: 0.4,
                        delay: 0,
                        options: [.curveEaseIn],
                        animations: {
                            stickerView.frame.origin.y = parent.bounds.maxY + stickerSize
                        },
                        completion: { _ in
                            stickerView.removeFromSuperview()
                        }
                    )
                }
            }
        )
    }
}
