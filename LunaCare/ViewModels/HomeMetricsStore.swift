//
//  HomeMetricsStore.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-09-27.
//

import Foundation

@MainActor
final class HomeMetricsStore: ObservableObject {
    static let shared = HomeMetricsStore()

    @Published private(set) var selected: [HealthMetric]

    private let defaultsKey = "home_metrics"
    private let userRepo = UserRepository()

    private init() {
        let raw = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        let parsed = Self.parse(raw)
        selected = parsed.isEmpty ? HealthMetric.defaults : parsed
    }

    func load(uid: String) {
        guard cloudEnabled(uid: uid) else { return }
        userRepo.fetchHomeMetrics(uid: uid) { [weak self] raw in
            Task { @MainActor in
                guard let self else { return }
                let parsed = Self.parse(raw ?? [])
                if parsed.isEmpty {
                    self.userRepo.setHomeMetrics(uid: uid, metrics: self.selected)
                } else {
                    self.selected = parsed
                    self.cache(parsed)
                }
            }
        }
    }

    func save(_ metrics: [HealthMetric], uid: String) {
        let clamped = metrics.isEmpty ? HealthMetric.defaults : Array(metrics.prefix(HealthMetric.maxSelected))
        selected = clamped
        cache(clamped)
        if cloudEnabled(uid: uid) {
            userRepo.setHomeMetrics(uid: uid, metrics: clamped)
        }
    }

    func resetToDefaults(uid: String) {
        save(HealthMetric.defaults, uid: uid)
    }

    private func cloudEnabled(uid: String) -> Bool {
        !uid.isEmpty && SyncManager.shared.isCloudSyncOn
    }

    private func cache(_ metrics: [HealthMetric]) {
        UserDefaults.standard.set(metrics.map(\.rawValue), forKey: defaultsKey)
    }

    private static func parse(_ raw: [String]) -> [HealthMetric] {
        var seen = Set<HealthMetric>()
        let metrics = raw.compactMap(HealthMetric.init(rawValue:)).filter { seen.insert($0).inserted }
        return Array(metrics.prefix(HealthMetric.maxSelected))
    }
}
