//
//  LocalMoodStore.swift
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
        // Assign an ID if missing so future edits can match by ID
        if normalized.id == nil {
            normalized.id = UUID().uuidString
        }

        // Remove by ID, or by createdAt within 1 second (handles Firestore timestamp
        // rounding where cloud and local entries for the same log have slightly
        // different timestamps and would otherwise both survive deduplication).
        existing.removeAll {
            ($0.id != nil && $0.id == normalized.id) ||
            (abs(($0.createdAt ?? .distantPast).timeIntervalSince(normalized.createdAt ?? .distantFuture)) < 1)
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

            // Use stored ID — it is now always guaranteed to exist
            // because saveOfflineMood assigns one when missing.
            let calendarId = log.id ?? UUID().uuidString

            return CalendarDayLog(
                id: calendarId,
                mood: moodEnum,
                note: log.notes,
                createdAt: createdAt
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
}
