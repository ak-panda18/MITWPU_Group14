//
//  wordTraceContentProvider.swift
//  AksharApp
//
//  Created by SDC-USER on 18/02/26.
//

import UIKit

final class WordTraceContentProvider {

    static func content(
        word: TracingWord
    ) -> (UIImage?, UIImage?, [String]) {

        let wordImage =
            UIImage(named: word.wordImageName)

        let illustration =
            word.imageName != nil ?
            UIImage(named: word.imageName!) : nil

        let maskNames =
            ["\(word.wordImageName)_mask"]

        return (
            wordImage,
            illustration,
            maskNames
        )
    }
}
