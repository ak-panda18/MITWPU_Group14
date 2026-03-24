import UIKit

final class WordTraceContentProvider {

    static func content(
        word: TracingWord
    ) -> (UIImage?, UIImage?, [String]) {

        let wordImage =
            UIImage(named: word.wordImageName)

        let illustration = word.imageName.flatMap { UIImage(named: $0) }
        let maskNames =
            ["\(word.wordImageName)_mask"]

        return (
            wordImage,
            illustration,
            maskNames
        )
    }
}
