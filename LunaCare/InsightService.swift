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
            let source = measurements.isEmpty ? FakeStruct.extremeHighRisk30Days() : measurements
            let weekly = WeeklyInsightService.shared.generateWeeklyInsights(measurements: source)
            LocalStorageInsights.shared.save(weekly)
            return weekly
        }

        do {
            // Load measurements from Firestore
            let measurements = try await repo.fetchLastDays(uid: uid, lastDays: 30)

            if !measurements.isEmpty {
                let weekly = WeeklyInsightService.shared.generateWeeklyInsights(measurements: measurements)
                LocalStorageInsights.shared.save(weekly)
                return weekly
            }

        } catch {
            print("Insight load failed: \(error)")
        }

        // Cloud returned nothing → try local cache, then fake data
        let cached = LocalStorageInsights.shared.load()
        if !cached.isEmpty { return cached }

        let fake = FakeStruct.extremeHighRisk30Days()
        let weekly = WeeklyInsightService.shared.generateWeeklyInsights(measurements: fake)
        LocalStorageInsights.shared.save(weekly)
        return weekly
    }
}
