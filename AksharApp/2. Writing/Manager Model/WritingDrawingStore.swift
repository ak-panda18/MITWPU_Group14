import Foundation
import PencilKit

final class WritingDrawingStore {

    // MARK: - Core read/write/delete
    func saveDrawing(_ drawing: PKDrawing,
                     index: Int, category: String,
                     stage: String, part: String = "main") {
        try? drawing.dataRepresentation().write(to: url(index: index,
                                                        category: category,
                                                        stage: stage,
                                                        part: part))
    }

    func loadDrawing(index: Int, category: String,
                     stage: String, part: String = "main") -> PKDrawing? {
        let fileURL = url(index: index, category: category, stage: stage, part: part)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? PKDrawing(data: data)
    }

    func deleteDrawing(index: Int, category: String,
                       stage: String, part: String = "main") {
        try? FileManager.default.removeItem(at: url(index: index,
                                                     category: category,
                                                     stage: stage,
                                                     part: part))
    }

    // MARK: - One-stage helpers
    func saveOneDrawing(_ drawing: PKDrawing, index: Int, category: String) {
        saveDrawing(drawing, index: index, category: category, stage: "one")
    }
    func loadOneDrawing(index: Int, category: String) -> PKDrawing? {
        loadDrawing(index: index, category: category, stage: "one")
    }
    func deleteOneDrawing(index: Int, category: String) {
        deleteDrawing(index: index, category: category, stage: "one")
    }

    // MARK: - Two-stage helpers
    func saveTwoDrawings(top: PKDrawing, bottom: PKDrawing, index: Int, category: String) {
        saveDrawing(top,    index: index, category: category, stage: "two", part: "top")
        saveDrawing(bottom, index: index, category: category, stage: "two", part: "bottom")
    }
    func loadTwoDrawings(index: Int, category: String) -> (PKDrawing, PKDrawing)? {
        guard let top    = loadDrawing(index: index, category: category, stage: "two", part: "top"),
              let bottom = loadDrawing(index: index, category: category, stage: "two", part: "bottom")
        else { return nil }
        return (top, bottom)
    }
    func deleteTwoDrawings(index: Int, category: String) {
        deleteDrawing(index: index, category: category, stage: "two", part: "top")
        deleteDrawing(index: index, category: category, stage: "two", part: "bottom")
    }

    // MARK: - Six-stage helpers
    func saveSixDrawings(_ drawings: [PKDrawing], index: Int, category: String) {
        for (i, d) in drawings.enumerated() {
            saveDrawing(d, index: index, category: category, stage: "six", part: "\(i)")
        }
    }
    func loadSixDrawings(index: Int, category: String) -> [PKDrawing]? {
        var result: [PKDrawing] = []
        for i in 0..<6 {
            guard let d = loadDrawing(index: index, category: category,
                                      stage: "six", part: "\(i)")
            else { return nil }
            result.append(d)
        }
        return result
    }
    func deleteSixDrawings(index: Int, category: String) {
        for i in 0..<6 {
            deleteDrawing(index: index, category: category, stage: "six", part: "\(i)")
        }
    }

    // MARK: - URL builder
    private func url(index: Int, category: String, stage: String, part: String) -> URL {
        let docs    = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeCat = category.replacingOccurrences(of: " ", with: "_")
        return docs.appendingPathComponent("trace_\(safeCat)_\(index)_\(stage)_\(part).data")
    }
}
