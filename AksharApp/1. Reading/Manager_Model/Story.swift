import Foundation

// MARK: - Root container
struct StoriesResponse: Codable {
    let stories: [Story]
}

// MARK: -Data Model
struct Story: Identifiable, Codable {
    let id: String
    let title: String
    let content: [StoryPage]
    let difficulty: String
    let coverImage: String
    let timesRead: Int
    var lastReadDate: Date?
}

struct StoryPage: Identifiable, Codable {
    let id: String
    let text: String
    let imageURL: String?
    let pageNumber: Int
    let checkAfter: Bool
}
