//
//  RandomizedQuestionCycle.swift
//  AksharApp
//
//  Created by SDC-USER on 06/01/26.
//

import Foundation

struct RandomizedQuestionCycle: Codable {
    private(set) var indices: [Int]
    private(set) var pointer: Int

    init(count: Int, startPointer: Int = 0) {
        self.indices = Array(0..<count)
        self.indices.shuffle()
        self.pointer = min(startPointer, count - 1)
    }

    mutating func currentIndex() -> Int {
        indices[pointer]
    }

    mutating func moveToNext() {
        pointer += 1
        if pointer >= indices.count {
            indices.shuffle()
            pointer = 0
        }
    }
}
