//
//  TraceContentProvider.swift
//  AksharApp
//
//  Created by SDC-USER on 18/02/26.
//

import UIKit

final class TraceContentProvider {

    static func paneImages(
        index: Int,
        contentType: WritingContentType
    ) -> ([UIImage?], [String]) {

        let char = WritingGameplayManager.shared.getCharacterString(
            for: index,
            contentType: contentType
        )

        switch contentType {
        case .words: fatalError("Words not supported in OneLetterTraceViewController")

        case .letters:
            let letterImg = UIImage(named: "letter_\(char)") ?? UIImage(named: char)
            let boxImg = UIImage(named: "box_\(char)")

            var images = Array(repeating: letterImg, count: 6)

            if let boxImg {
                images[4] = boxImg
                images[5] = boxImg
            }

            return (images, ["\(char)_mask"])

        case .numbers:
            let numImg = UIImage(named: "number_\(index)")
            let boxImg = UIImage(named: "box_\(index)")

            var images = Array(repeating: numImg, count: 6)

            if let boxImg {
                images[4] = boxImg
                images[5] = boxImg
            }

            return (images, ["\(index)_mask"])
        }
    }
}
