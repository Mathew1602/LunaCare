//
//  InsightUploadManager.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-25.
//

import Foundation

final class InsightUploadManager {

    static let shared = InsightUploadManager()
    private init() {}

    func uploadWeeklyInsights(uid: String, insights: [WeeklyInsight]) {
        let path = FSPath.insights(uid)
        let fm = FirestoreManager.shared

        for insight in insights {
            let payload: [String: Any] = [
                "metric": insight.metric,
                "text": insight.text,
                "last7Avg": insight.last7Avg,
                "prev7Avg": insight.prev7Avg,
                "delta": insight.delta,
                "percentChange": insight.percentChange,
                "direction": insight.direction,
                "createdAt": insight.createdAt
            ]

            fm.add(collectionPath: path, data: payload)
        }
    }
}
