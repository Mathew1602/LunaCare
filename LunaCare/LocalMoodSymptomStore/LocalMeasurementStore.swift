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

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Write

    func save(_ measurement: Measurement) {
        var existing = loadAll()
        existing.removeAll { $0.date == measurement.date }
        existing.append(measurement)
        persist(existing)
    }

    func saveMany(_ measurements: [Measurement]) {
        var existing = loadAll()
        for m in measurements {
            existing.removeAll { $0.date == m.date }
            existing.append(m)
        }
        persist(existing)
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Read

    func fetchLastDays(_ days: Int = 30) -> [Measurement] {
        let cutoff = cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cutoffStr = dateFormatter.string(from: cutoff)
        return loadAll()
            .filter { $0.date >= cutoffStr }
            .sorted { $0.date < $1.date }
    }

    func fetchLatest() -> Measurement? {
        loadAll().sorted { $0.date < $1.date }.last
    }

    func fetchRange(from: Date, to: Date) -> [Measurement] {
        let fromStr = dateFormatter.string(from: from)
        let toStr = dateFormatter.string(from: to)
        return loadAll()
            .filter { $0.date >= fromStr && $0.date <= toStr }
            .sorted { $0.date < $1.date }
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
