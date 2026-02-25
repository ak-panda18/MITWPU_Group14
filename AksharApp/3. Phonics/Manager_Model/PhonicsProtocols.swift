//
//  PhonicsProtocols.swift
//  AksharApp
//
//  Created by SDC-USER on 09/12/25.
//

import Foundation

protocol ExerciseReceivesCover {
    var exerciseType: ExerciseType? { get set }
    var coverWasShown: Bool { get set }
}

protocol ExerciseResumable {
    var startingIndex: Int? { get set }
}

protocol ExerciseProgressReporting {
    var currentIndex: Int { get }
}
