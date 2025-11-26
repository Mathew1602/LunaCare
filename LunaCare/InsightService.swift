//
//  InsightService.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//



import Foundation
import FirebaseFirestore

final class InsightService {

    static let shared = InsightService()
    private init() {}

    /// Load → local first → fallback to fake → compute insights → save → upload if needed
    func load(uid: String, cloudSyncOn: Bool, completion: @escaping ([WeeklyInsight]) -> Void) {

        // Try locally first
        let local = LocalStorageInsights.shared.load()
        if !local.isEmpty {
            completion(local)
            return
        }

        // Fallback → generate fake measurement data
        let fake = FakeMeasurementData.generate30Days()

        // Run Mathew’s model (weekly insights)
        let generated = WeeklyInsightService.shared.generateWeeklyInsights(measurements: fake)

        // Save locally always
        LocalStorageInsights.shared.save(generated)

        // Upload to cloud only if enabled
        if cloudSyncOn {
            for insight in generated {
                upload(uid: uid, insight: insight)
            }
        }

        completion(generated)
    }

    // Upload a single weekly insight
    private func upload(uid: String, insight: WeeklyInsight) {

        let data: [String: Any] = [
            "metric": insight.metric,
            "text": insight.text,
            "last7Avg": insight.last7Avg,
            "prev7Avg": insight.prev7Avg,
            "delta": insight.delta,
            "percentChange": insight.percentChange,
            "direction": insight.direction,
            "createdAt": insight.createdAt
        ]

        FirestoreManager.shared.add(
            collectionPath: "users/\(uid)/weekly_insights",
            data: data
        )
    }
}
