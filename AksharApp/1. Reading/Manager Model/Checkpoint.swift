import Foundation

struct CheckpointsResponse: Codable {
    let checkpoints: [CheckpointSet]
}

struct CheckpointSet: Identifiable, Codable {
    let id: String
    var content: [CheckpointItem] = []
    var timesRead: Int = 0
}

struct CheckpointItem: Identifiable, Codable {
    let id: String
    var text: String
    var imageURL: String?
    var pageNumber: Int
}
