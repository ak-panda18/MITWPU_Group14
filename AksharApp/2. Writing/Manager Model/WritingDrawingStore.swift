import Foundation
import PencilKit
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AksharApp",
                            category: "WritingDrawingStore")

final class WritingDrawingStore {
    
    private let childManager: ChildManager

    init(childManager: ChildManager) {
        self.childManager = childManager
    }

    private var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var childDirectory: URL {
        let id  = childManager.currentChild.id?.uuidString ?? "default"
        let dir = documents
            .appendingPathComponent("drawings", isDirectory: true)
            .appendingPathComponent(id, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Core read/write/delete

    func saveDrawing(_ drawing: PKDrawing,
                     index: Int, category: String,
                     stage: String, part: String = "main") {
        let dest = url(index: index, category: category, stage: stage, part: part)
        do {
            // .atomic writes to a temp file first, then renames — prevents
            // corrupt files if the app is killed mid-write.
            try drawing.dataRepresentation().write(to: dest, options: .atomic)
        } catch {
            logger.error("WritingDrawingStore: save failed [\(category)/\(index)/\(stage)/\(part)] – \(error)")
        }
    }

    func loadDrawing(index: Int, category: String,
                     stage: String, part: String = "main") -> PKDrawing? {
        let fileURL = url(index: index, category: category, stage: stage, part: part)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            return try PKDrawing(data: data)
        } catch {
            // File exists but is corrupt (e.g. truncated write). Log it so it
            // can be investigated; return nil so the caller shows a blank canvas.
            logger.error("WritingDrawingStore: corrupt drawing [\(category)/\(index)/\(stage)/\(part)] – \(error)")
            return nil
        }
    }

    func deleteDrawing(index: Int, category: String,
                       stage: String, part: String = "main") {
        let target = url(index: index, category: category, stage: stage, part: part)
        guard FileManager.default.fileExists(atPath: target.path) else { return }
        do {
            try FileManager.default.removeItem(at: target)
        } catch {
            logger.error("WritingDrawingStore: delete failed [\(category)/\(index)/\(stage)/\(part)] – \(error)")
        }
    }

    // MARK: - Cleanup
    func deleteAllDrawings(for category: String) {
        let safeCat = category.replacingOccurrences(of: " ", with: "_")
        let prefix  = "trace_\(safeCat)_"
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: childDirectory, includingPropertiesForKeys: nil) else { return }
        var deleted = 0
        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            do {
                try FileManager.default.removeItem(at: file)
                deleted += 1
            } catch {
                logger.error("WritingDrawingStore: could not delete \(file.lastPathComponent) – \(error)")
            }
        }
        logger.info("WritingDrawingStore: purged \(deleted) file(s) for category '\(category)'")
    }

    // Deletes every drawing for the CURRENT child. Call on account deletion.
    func deleteAllDrawings() {
        do {
            try FileManager.default.removeItem(at: childDirectory)
        } catch {
            logger.error("WritingDrawingStore: could not delete child drawings – \(error)")
        }
    }

    // One-time cleanup of the old shared files in Documents (they can't be attributed to any account).
    func purgeLegacyUnscopedDrawings() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: documents, includingPropertiesForKeys: nil) else { return }
        for file in files where file.lastPathComponent.hasPrefix("trace_") && file.pathExtension == "data" {
            try? FileManager.default.removeItem(at: file)
        }
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
        let loaded = (0..<6).compactMap { i in
            loadDrawing(index: index, category: category, stage: "six", part: "\(i)")
        }
        // Return nil if any of the 6 parts is missing, so the caller
        // knows the set is incomplete rather than silently showing fewer strokes.
        guard loaded.count == 6 else { return nil }
        return loaded
    }
    func deleteSixDrawings(index: Int, category: String) {
        (0..<6).forEach { i in
            deleteDrawing(index: index, category: category, stage: "six", part: "\(i)")
        }
    }

    // MARK: - URL builder

    private func url(index: Int, category: String, stage: String, part: String) -> URL {
        let safeCat = category.replacingOccurrences(of: " ", with: "_")
        return childDirectory.appendingPathComponent("trace_\(safeCat)_\(index)_\(stage)_\(part).data")
    }
}
