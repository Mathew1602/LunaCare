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
        persist(existing)

        if let id = normalized.id, let createdAt = normalized.createdAt {
            LocalMoodCalendarStore.shared.save(CalendarDayLog(
                id: id,
                mood: Mood(score: normalized.mood),
                note: normalized.notes,
                createdAt: createdAt
            ))
        }
    }

    func loadOfflineMoods() -> [MoodLog] {
        guard let data = StorageScope.data(forKey: key),
              var logs = try? JSONDecoder().decode([MoodLog].self, from: data) else {
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

    private func persist(_ logs: [MoodLog]) {
        if let data = try? JSONEncoder().encode(logs) {
            StorageScope.set(data, forKey: key)
        }
    }

    func deleteOfflineMood(id: String) {
        var existing = loadOfflineMoods()
        existing.removeAll { $0.id == id }
        persist(existing)
    }

    func clearOfflineMoods() {
        StorageScope.removeObject(forKey: key)
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

            return CalendarDayLog(
                id: log.id ?? UUID().uuidString,
                mood: Mood(score: log.mood),
                note: log.notes,
                createdAt: createdAt
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
}
