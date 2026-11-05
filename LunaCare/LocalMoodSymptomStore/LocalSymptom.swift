//
//  LocalSymptomWatch.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-15.
//  Updated by Xiaoya for deleting function.

import Foundation

final class LocalSymptomStore {
    static let shared = LocalSymptomStore()
    private init() {}

    private let key = "offline_watch_symptom_logs"

    func saveOfflineSymptomLog(_ payload: SymptomLogPayload, createdAt: Date = Date()) {
        save(LocalSymptomLog(payload: payload, createdAt: createdAt))
    }

    func loadOfflineSymptomLogs() -> [LocalSymptomLog] {
        guard let data = StorageScope.data(forKey: key),
              var logs = try? JSONDecoder().decode([LocalSymptomLog].self, from: data) else {
            return []
        }
        if logs.contains(where: { $0.id == nil }) {
            for i in logs.indices where logs[i].id == nil {
                logs[i].id = UUID().uuidString
            }
            persist(logs)
        }
        return logs
    }

    /// Save a pre-built log (preserves its original createdAt). Deduplicates by id, or by createdAt within 1 second.
    func save(_ log: LocalSymptomLog) {
        var normalized = log
        if normalized.id == nil { normalized.id = LocalSymptomLog.dayID(for: normalized.createdAt) }
        var existing = loadOfflineSymptomLogs()
        existing.removeAll {
            $0.id == normalized.id || abs($0.createdAt.timeIntervalSince(normalized.createdAt)) < 1
        }
        existing.append(normalized)
        persist(existing)
    }

    private func persist(_ logs: [LocalSymptomLog]) {
        if let data = try? JSONEncoder().encode(logs) {
            StorageScope.set(data, forKey: key)
        }
    }
    
    func deleteOfflineSymptomLog(createdAt: Date) {
        var existing = loadOfflineSymptomLogs()
        existing.removeAll { abs($0.createdAt.timeIntervalSince(createdAt)) < 1 }
        persist(existing)
    }

    func clearOfflineSymptomLogs() {
        StorageScope.removeObject(forKey: key)
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

                return SymptomLogSummary(id: item.id ?? LocalSymptomLog.dayID(for: item.createdAt), createdAt: item.createdAt, rows: rows)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
