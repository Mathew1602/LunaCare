//
//  WeeklyInsightService.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-25.
//


import Foundation

final class WeeklyInsightService {

    static let shared = WeeklyInsightService()
    private init() {}

    
    func generateWeeklyInsights(measurements: [Measurement]) -> [WeeklyInsight] {

        var results: [WeeklyInsight] = []

        for metric in InsightMetric.allCases {
            if let r = InsightEngine.compareLast7vsPrev7(records: measurements, metric: metric),
               let text = InsightEngine.makeText(records: measurements, metric: metric) {

                let insight = WeeklyInsight(
                    id: UUID().uuidString,
                    metric: metric.label,
                    text: text,
                    last7Avg: r.last7Avg,
                    prev7Avg: r.prev7Avg,
                    delta: r.delta,
                    percentChange: r.percentChange,
                    direction: r.direction,
                    createdAt: Date(),
                    localOnly: true     // will be flipped to false when successfully uploaded
                )

                results.append(insight)
            }
        }

        return results
    }
}
