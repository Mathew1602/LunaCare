//
//  LocalSymptomWatch.swift
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

    /// Save a pre-built log (preserves its original createdAt). Deduplicates by createdAt within 1 second.
    func save(_ log: LocalSymptomLog) {
        var existing = loadOfflineSymptomLogs()
        existing.removeAll { abs($0.createdAt.timeIntervalSince(log.createdAt)) < 1 }
        existing.append(log)
        if let data = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func clearOfflineSymptomLogs() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    func offlineSymptomHistory(from: Date, to: Date) -> [SymptomLogSummary] {
        let all = loadOfflineSymptomLogs()

        let filtered = all.filter { log in
            log.createdAt >= from && log.createdAt <= to
        }

        return filtered
            .map { item in
                let rows = item.payload.values
                    .map { SymptomRow(name: $0.key, value: $0.value) }
                    .sorted { $0.value > $1.value }

                return SymptomLogSummary(createdAt: item.createdAt, rows: rows)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
