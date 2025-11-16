//
//  LocalSymptomWatchSyncServiceHelper.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-15.
//

import Foundation

final class LocalSymptomStore {
    static let shared = LocalSymptomStore()
    private init() {}

    private let key = "offline_watch_symptom_logs"

    func saveOfflineSymptomLog(_ payload: SymptomLogPayload) {
        var existing = loadOfflineSymptomLogs()
        let log = LocalSymptomLog(payload: payload, createdAt: Date())
        existing.append(log)

        if let data = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func loadOfflineSymptomLogs() -> [LocalSymptomLog] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let logs = try? JSONDecoder().decode([LocalSymptomLog].self, from: data) else {
            return []
        }
        return logs
    }

    func clearOfflineSymptomLogs() {
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    /// Returns SymptomDaySummary for days between from/to, newest first.
    func offlineSymptomHistory(from: Date, to: Date) -> [SymptomDaySummary] {
        let logs = loadOfflineSymptomLogs()
        let cal = Calendar.current

        // Filter into range and group by day
        var perDayValues: [Date: [String: Int]] = [:]

        for item in logs {
            let createdAt = item.createdAt
            guard createdAt >= from, createdAt <= to else { continue }

            let dayKey = cal.startOfDay(for: createdAt)
            var bucket = perDayValues[dayKey] ?? [:]

            for (name, value) in item.payload.values {
                bucket[name, default: 0] += value
            }

            perDayValues[dayKey] = bucket
        }

        // Convert to SymptomDaySummary
        var summaries: [SymptomDaySummary] = []

        for (day, values) in perDayValues {
            let rows = values
                .map { SymptomRow(name: $0.key, value: $0.value) }
                .sorted { $0.value > $1.value }

            if !rows.isEmpty {
                summaries.append(
                    SymptomDaySummary(date: day, rows: rows)
                )
            }
        }

        return summaries.sorted { $0.date > $1.date }
    }
}
