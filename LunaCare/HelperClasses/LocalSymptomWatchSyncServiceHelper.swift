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

    func saveOfflineSymptomLog(_ log: SymptomLogPayload) {
        var existing = loadOfflineSymptomLogs()

        existing.append(log)

        if let data = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // Load all symptom logs stored offline
    func loadOfflineSymptomLogs() -> [SymptomLogPayload] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let logs = try? JSONDecoder().decode([SymptomLogPayload].self, from: data) else {
            return []
        }
        return logs
    }

    // Clear all offline symptom logs
    func clearOfflineSymptomLogs() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
