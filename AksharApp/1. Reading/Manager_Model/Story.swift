//
//  Story.swift
//  AksharApp
//
//  Created by Akshita Panda on 26/11/25.
//

import Foundation

struct StoriesResponse: Codable {
    var stories: [Story] = []

    init() {
        do {
            let response = try load()
            stories = response.stories
        } catch {
            print("StoriesResponse init error:", error.localizedDescription)
        }
    }

    enum CodingKeys: String, CodingKey {
        case stories
    }

    func getRandomStory() -> Story? {
        return stories.randomElement()
    }

    func getStories(difficulty: String) -> [Story] {
        return stories.filter { $0.difficulty == difficulty }
    }

    func getStory(by id: String) -> Story? {
        stories.first { $0.id == id }
    }
}

struct Story: Identifiable, Codable {

    let id: String
    var title: String
    var content: [StoryPage]
    var difficulty: String
    var coverImage: String
    var timesRead: Int
    var lastReadDate: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case difficulty
        case coverImage
        case timesRead
        case lastReadDate
    }
}

struct StoryPage: Identifiable, Codable {
    let id: String
    var text: String
    var imageURL: String?
    var pageNumber: Int
    var checkAfter: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case imageURL
        case pageNumber
        case checkAfter
    }
}

extension StoriesResponse {
    
    func load(from filename: String = "stories") throws -> StoriesResponse {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            throw NSError(domain: "StoriesResponse", code: 404,
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

        return try decoder.decode(StoriesResponse.self, from: data)
    }

    func decode(from data: Data) throws -> StoriesResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StoriesResponse.self, from: data)
    }
}

extension StoriesResponse {

    var storiesByDifficulty: [String: [Story]] {
        var grouped: [String: [Story]] = [:]
        for story in stories {
            grouped[story.difficulty, default: []].append(story)
        }
        return grouped
    }
}

