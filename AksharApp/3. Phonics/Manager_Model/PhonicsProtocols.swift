//
//  PhonicsProtocols.swift
//  AksharApp
//
//  Created by SDC-USER on 09/12/25.
//

import Foundation

// Defines a VC that can show a cover screen before starting
protocol ExerciseReceivesCover {
    var exerciseType: ExerciseType? { get set }
    var coverWasShown: Bool { get set }
}

// Defines a VC that can resume from a specific question index
protocol ExerciseResumable {
    var startingIndex: Int? { get set }
}

// Defines a VC that reports progress (like "Question 3 of 10")
protocol ExerciseProgressReporting {
    var currentIndex: Int { get }
}
