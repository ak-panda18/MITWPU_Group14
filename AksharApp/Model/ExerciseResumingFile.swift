//
//  ExerciseResumingFile.swift
//  AksharApp
//
//  Created by SDC-USER on 11/12/25.
//
import Foundation

protocol ExerciseResumable {
    var startingIndex: Int? { get set }
}

protocol ExerciseProgressReporting {
    var currentIndex: Int { get }
}

