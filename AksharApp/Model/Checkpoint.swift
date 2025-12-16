//
//  Checkpoint.swift
//  AksharApp
//
//  Created by Akshita Panda on 27/11/25.
//


import Foundation


struct CheckpointsResponse: Codable {
    var checkpoints: [CheckpointSet] = []

    init() {
        do {
            let response = try load()
            checkpoints = response.checkpoints
        } catch {
            print("CheckpointsResponse init error:", error.localizedDescription)
        }
    }

    enum CodingKeys: String, CodingKey {
        case checkpoints
    }

    // MARK: - Convenience lookups
    func checkpointSet(for storyId: String) -> CheckpointSet? {
        return checkpoints.first { $0.id == storyId }
    }

    func items(for storyId: String) -> [CheckpointItem] {
        return checkpointSet(for: storyId)?.content ?? []
    }

    func item(for storyId: String, pageNumber: Int) -> CheckpointItem? {
        return items(for: storyId).first { $0.pageNumber == pageNumber }
    }

    var checkpointsById: [String: CheckpointSet] {
        var dict: [String: CheckpointSet] = [:]
        for set in checkpoints {
            dict[set.id] = set
        }
        return dict
    }
}

struct CheckpointSet: Identifiable, Codable {
    let id: String
    var content: [CheckpointItem] = []
    var timesRead: Int = 0

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case timesRead
    }
}

struct CheckpointItem: Identifiable, Codable {
    let id: String
    var text: String
    var imageURL: String?
    var pageNumber: Int

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case imageURL
        case pageNumber
    }
}

// MARK: - Loading helpers (mirrors StoriesResponse approach)

extension CheckpointsResponse {

    func load(from filename: String = "checkpoints") throws -> CheckpointsResponse {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            throw NSError(domain: "CheckpointsResponse", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "\(filename).json not found"])
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        #if DEBUG
        if let s = String(data: data, encoding: .utf8) {
            print("Loaded \(filename).json — \(s.prefix(200))...")
        }
        #endif

        return try decoder.decode(CheckpointsResponse.self, from: data)
    }
    func decode(from data: Data) throws -> CheckpointsResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CheckpointsResponse.self, from: data)
    }
}

