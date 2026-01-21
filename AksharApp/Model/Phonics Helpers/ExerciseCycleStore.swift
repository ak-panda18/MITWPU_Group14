//
//  ExerciseCycleStore.swift
//  AksharApp
//
//  Created by SDC-USER on 06/01/26.
//

import Foundation

enum ExerciseCycleStore {

    static func save(_ cycle: RandomizedQuestionCycle, key: String) {
        if let data = try? JSONEncoder().encode(cycle) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load(key: String) -> RandomizedQuestionCycle? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let cycle = try? JSONDecoder().decode(RandomizedQuestionCycle.self, from: data)
        else {
            return nil
        }
        return cycle
    }

    static func clear(key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
