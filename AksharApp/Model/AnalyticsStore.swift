//
//  AnalyticsStore.swift
//  AksharApp
//
//  Created by Akshita Panda on 10/01/26.
//
import Foundation

final class AnalyticsStore {

    // MARK: - Singleton
    static let shared = AnalyticsStore()
    private init() {}

    // MARK: - File URL
    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("analytics.json")
    }

    // MARK: - Load
    private func loadData() -> AnalyticsData {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return AnalyticsData.empty
        }

        do {
            let data = try Data(contentsOf: fileURL)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            return try decoder.decode(AnalyticsData.self, from: data)
        } catch {
            print("Failed to load analytics.json:", error)
            return AnalyticsData.empty
        }
    }

    // MARK: - Save
    private func saveData(_ data: AnalyticsData) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601

            let encoded = try encoder.encode(data)
            try encoded.write(to: fileURL, options: .atomic)

            print("analytics.json saved")
        } catch {
            print("Failed to save analytics.json:", error)
        }
    }
    func saveOrUpdateWritingSession(_ session: WritingSessionData) {
            var data = loadData()
            
            // Check if session with this ID already exists
            if let index = data.writingSessions.firstIndex(where: { $0.id == session.id }) {
                // UPDATE existing
                data.writingSessions[index] = session
                print("Analytics: Updated session \(session.id)")
            } else {
                // APPEND new
                data.writingSessions.append(session)
                print("Analytics: Created new session \(session.id)")
            }
            
            saveData(data)
        }

    // MARK: - Append APIs

    func appendReadingSession(_ session: ReadingSessionData) {
        var data = loadData()
        data.readingSessions.append(session)
        saveData(data)
    }

    func updateReadingSessionEnd(
        sessionId: UUID,
        endTime: Date
    ) {
        var data = loadData()
        guard let index = data.readingSessions.firstIndex(where: { $0.id == sessionId }) else {
            return
        }

        data.readingSessions[index].endTime = endTime
        saveData(data)
    }

    func appendCheckpointResult(_ result: ReadingCheckpointResultData) {
        var data = loadData()
        data.readingCheckpointResults.append(result)
        saveData(data)
    }

    func appendPhonicsSession(_ session: PhonicsSessionData) {
        var data = loadData()
        data.phonicsSessions.append(session)
        saveData(data)
    }
    
    func appendWritingSession(_ session: WritingSessionData) {
        var data = loadData()
        data.writingSessions.append(session)
        saveData(data)
    }

    // MARK: - Fetch APIs (for Analytics screen)

    func fetchReadingSessions() -> [ReadingSessionData] {
        loadData().readingSessions
    }

    func fetchCheckpointResults() -> [ReadingCheckpointResultData] {
        loadData().readingCheckpointResults
    }

    func fetchPhonicsSessions() -> [PhonicsSessionData] {
        loadData().phonicsSessions
    }
    
    func fetchWritingSessions() -> [WritingSessionData] {
        loadData().writingSessions
    }
}

