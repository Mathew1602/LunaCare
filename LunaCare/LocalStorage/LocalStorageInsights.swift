//
//  LocalStorageInsights.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-25.
//

import Foundation

final class LocalStorageInsights {

    static let shared = LocalStorageInsights()
    private init() {}

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("weekly_insights.json")
    }

    func save(_ insights: [WeeklyInsight]) {
        do {
            let data = try JSONEncoder().encode(insights)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save insights locally:", error)
        }
    }

    func load() -> [WeeklyInsight] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([WeeklyInsight].self, from: data)
        } catch {
            return []
        }
    }
}
