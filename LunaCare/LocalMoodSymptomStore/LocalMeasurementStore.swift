//
//  LocalMeasurementStore.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-14.
//

import Foundation

final class LocalMeasurementStore {
    static let shared = LocalMeasurementStore()
    private init() {}

    private let key = "offline_measurements"
    private let cal = Calendar.current

    // MARK: - Write

    func save(_ measurement: Measurement) {
        var existing = loadAll()
        existing.removeAll { $0.dayKey == measurement.dayKey }
        existing.append(measurement)
        persist(existing)
    }

    func saveMany(_ measurements: [Measurement]) {
        var existing = loadAll()
        for m in measurements {
            existing.removeAll { $0.dayKey == m.dayKey }
            existing.append(m)
        }
        persist(existing)
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Read

    func fetchLastDays(_ days: Int = 30) -> [Measurement] {
        let cutoff = cal.startOfDay(for: cal.date(byAdding: .day, value: -days, to: Date()) ?? Date())
        return loadAll()
            .filter { $0.createdAt >= cutoff }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func fetchLatest() -> Measurement? {
        loadAll().sorted { $0.createdAt < $1.createdAt }.last
    }

    func fetchRange(from: Date, to: Date) -> [Measurement] {
        let start = cal.startOfDay(for: from)
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: to)) ?? to
        return loadAll()
            .filter { $0.createdAt >= start && $0.createdAt < end }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func loadAll() -> [Measurement] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let measurements = try? JSONDecoder().decode([Measurement].self, from: data)
        else { return [] }
        return measurements
    }

    func persist(_ measurements: [Measurement]) {
        if let data = try? JSONEncoder().encode(measurements) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
