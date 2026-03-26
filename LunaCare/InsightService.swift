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

        guard !uid.isEmpty else { return [] }

        do {
            // Load measurements already in Firestore
            let measurements = try await repo.fetchLastDays(uid: uid, lastDays: 30)

            if !measurements.isEmpty {
                let weekly = WeeklyInsightService.shared.generateWeeklyInsights(measurements: measurements)
                LocalStorageInsights.shared.save(weekly)
                return weekly
            }

        } catch {
            print("⚠️ Insight load failed: \(error)")
        }

        // If nothing in cloud → fallback to Mathew’s dataset
        let fake = FakeStruct.extremeHighRisk30Days()
        let weekly = WeeklyInsightService.shared.generateWeeklyInsights(measurements: fake)
        LocalStorageInsights.shared.save(weekly)
        return weekly
    }
}
