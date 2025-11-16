//
//  LocalMoodStoreWatchSyncServiceHelper.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-14.
//

import Foundation

final class LocalMoodStore {
    static let shared = LocalMoodStore()
    private init() {}

    private let key = "offline_watch_mood_logs"

    func saveOfflineMood(_ log: MoodLog) {
        var existing = loadOfflineMoods()

        var normalized = log
        if normalized.createdAt == nil {
            normalized.createdAt = Date()
        }

        existing.append(normalized)

        if let data = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func loadOfflineMoods() -> [MoodLog] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let logs = try? JSONDecoder().decode([MoodLog].self, from: data) else {
            return []
        }
        return logs
    }

    func clearOfflineMoods() {
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    /// Returns CalendarDayLog objects between the given dates, newest first.
    func offlineMoodHistory(from: Date, to: Date) -> [CalendarDayLog] {
        let logs = loadOfflineMoods()

        return logs.compactMap { log in
            guard
                let createdAt = log.createdAt,
                createdAt >= from,
                createdAt <= to
            else {
                return nil
            }

            let moodEnum: Mood
            switch log.mood {
            case 4:  moodEnum = .ecstatic
            case 2:  moodEnum = .happy
            case 0:  moodEnum = .okay
            case -1: moodEnum = .sad
            case -2: moodEnum = .angry
            default: moodEnum = .okay
            }

            return CalendarDayLog(
                mood: moodEnum,
                note: log.notes,
                createdAt: createdAt
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
}
