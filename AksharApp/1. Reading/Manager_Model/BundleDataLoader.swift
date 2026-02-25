//
//  BundleDataLoader.swift
//  AksharApp
//
//  Created by Akshita Panda on 19/02/26.
//
import Foundation

class BundleDataLoader {
    static let shared = BundleDataLoader()
    private init() {}
    
    func load<T: Decodable>(_ filename: String, as type: T.Type) -> T {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            fatalError("BundleDataLoader: \(filename).json not found")
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            fatalError("BundleDataLoader: Error decoding \(filename).json: \(error)")
        }
    }
}
