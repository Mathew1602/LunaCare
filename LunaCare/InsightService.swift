//
//  InsightService.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation

@MainActor
final class InsightService {

    static let shared = InsightService()
    private init() {}

    private let repo = MeasurementRepository()

    func loadInsights(uid: String) async -> [WeeklyInsight] {

        // Guest / local-only mode: load measurements from local store
        if uid.isEmpty {
            let measurements = LocalMeasurementStore.shared.fetchLastDays(30)
            guard !measurements.isEmpty else { return [] }

            let weekly = WeeklyInsightService.shared.generateWeeklyInsights(measurements: measurements)
            LocalStorageInsights.shared.save(weekly)
            return weekly
        }

        do {
            // Load measurements from Firestore
            let measurements = try await repo.fetchLastDays(uid: uid, lastDays: 30)
            guard !measurements.isEmpty else { return [] }

            let weekly = WeeklyInsightService.shared.generateWeeklyInsights(measurements: measurements)
            LocalStorageInsights.shared.save(weekly)
            return weekly

        } catch {
            print("Insight load failed: \(error)")
            return LocalStorageInsights.shared.load()
        }
    }
}
