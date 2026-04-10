//
//  LocalMoodCalendarStore.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-14.
//

import Foundation

final class LocalMoodCalendarStore {
    static let shared = LocalMoodCalendarStore()
    private init() {}

    private let key = "offline_mood_calendar_logs"
    private let cal = Calendar.current

    // MARK: - Write

    func save(_ log: CalendarDayLog) {
        var existing = loadAll()
        existing.removeAll { $0.id == log.id }
        existing.append(log)
        persist(existing)
    }

    /// Bulk-save cloud logs, deduplicating by createdAt (within 1 second)
    /// so that re-downloading doesn't create duplicates even when IDs differ.
    func saveMany(_ logs: [CalendarDayLog]) {
        var existing = loadAll()
        for log in logs {
            existing.removeAll {
                $0.id == log.id ||
                abs($0.createdAt.timeIntervalSince(log.createdAt)) < 1
            }
            existing.append(log)
        }
        persist(existing)
    }

    func updateLog(logId: String, newMood: Mood, newNote: String) {
        var existing = loadAll()
        guard let idx = existing.firstIndex(where: { $0.id == logId }) else { return }
        let old = existing[idx]
        existing[idx] = CalendarDayLog(
            id: old.id,
            mood: newMood,
            note: newNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : newNote.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: old.createdAt
        )
        persist(existing)
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Read
    func fetchMonth(monthStart: Date) -> [Date: [CalendarDayLog]] {
        guard let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) else {
            return [:]
        }

        let logs = loadAll().filter {
            $0.createdAt >= monthStart && $0.createdAt < monthEnd
        }

        var map: [Date: [CalendarDayLog]] = [:]
        for log in logs {
            let key = cal.startOfDay(for: log.createdAt)
            map[key, default: []].append(log)
        }

        for key in map.keys {
            map[key]?.sort { $0.createdAt > $1.createdAt }
        }
        return map
    }

    func fetchRange(from: Date, to: Date) -> [CalendarDayLog] {
        loadAll()
            .filter { $0.createdAt >= from && $0.createdAt < to }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Private helpers

    private func loadAll() -> [CalendarDayLog] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let logs = try? JSONDecoder().decode([CalendarDayLog].self, from: data)
        else { return [] }
        return logs
    }

    private func persist(_ logs: [CalendarDayLog]) {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
