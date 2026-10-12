//
//  HealthDataPersistence.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-09-27.
//

import Foundation

@MainActor
final class HealthDataPersistence {
    static let shared = HealthDataPersistence()

    private let repo = MeasurementRepository()
    private let pendingKey = "pendingHealthUploadDays"
    private var isUploading = false

    private init() {}

    func persist(_ records: [Measurement], uid: String) async {
        let local = LocalMeasurementStore.shared
        let existingByDay = Dictionary(local.loadAll().map { ($0.dayKey, $0) }, uniquingKeysWith: { _, new in new })

        let changed: [Measurement] = records.compactMap { record in
            guard let existing = existingByDay[record.dayKey] else { return record }
            guard Self.healthSignature(record) != Self.healthSignature(existing) else { return nil }
            var merged = record
            merged.id = existing.id ?? record.id
            merged.mood1to5 = existing.mood1to5
            merged.bleeding1to10 = existing.bleeding1to10
            merged.hairLoss1to10 = existing.hairLoss1to10
            merged.appetiteIssue1to10 = existing.appetiteIssue1to10
            merged.sleepTrouble1to10 = existing.sleepTrouble1to10
            merged.fatigue1to10 = existing.fatigue1to10
            return merged
        }

        if !changed.isEmpty {
            local.saveMany(changed)
        }

        guard !uid.isEmpty, SyncManager.shared.isCloudSyncOn else { return }

        var pending = pendingDays
        pending.formUnion(changed.map(\.dayKey))
        pendingDays = pending

        guard !pending.isEmpty, !isUploading else { return }
        isUploading = true
        defer { isUploading = false }

        let toUpload = local.loadAll().filter { pending.contains($0.dayKey) }
        do {
            _ = try await repo.upsertMany(uid: uid, measurements: toUpload)
            pendingDays = pendingDays.subtracting(toUpload.map(\.dayKey))
        } catch {
            print("Health upload failed, will retry: \(error.localizedDescription)")
        }
    }

    private var pendingDays: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: pendingKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: pendingKey) }
    }

    private static func healthSignature(_ m: Measurement) -> [Double?] {
        [
            m.steps.map(Double.init), m.distanceWalkedKm, m.flightsClimbed,
            m.activeEnergyKcal, m.basalEnergyKcal, m.exerciseMinutes, m.standHours,
            m.avgHeartRateBpm, m.restingHRBpm, m.walkingHeartRateAvgBpm, m.hrvSDNNms,
            m.respiratoryRateBpm, m.oxygenSaturationPct, m.vo2Max,
            m.sleepHours, m.deepSleepHours, m.remSleepHours, m.coreSleepHours,
            m.sleepEfficiencyPct, m.wakeAfterSleepOnsetMin, m.weightKg
        ]
    }
}
