import UIKit

final class TraceContentProvider {

    private let writingGameplayManager: WritingGameplayManager

    init(writingGameplayManager: WritingGameplayManager) {
        self.writingGameplayManager = writingGameplayManager
    }

    func paneImages(
        index: Int,
        contentType: WritingContentType
    ) -> ([UIImage?], [String]) {

        let char = writingGameplayManager.getCharacterString(
            for: index,
            contentType: contentType
        )

        switch contentType {
        case .words:
            preconditionFailure("TraceContentProvider does not handle .words — use WordTraceContentProvider instead.")

        case .letters:
            let letterImg = UIImage(named: "letter_\(char)") ?? UIImage(named: char)
            let boxImg    = UIImage(named: "box_\(char)")

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
