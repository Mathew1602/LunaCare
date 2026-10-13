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

    
    func generateWeeklyInsights(
        measurements: [Measurement],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [WeeklyInsight] {

        var results: [WeeklyInsight] = []

        for metric in InsightMetric.allCases {
            guard let r = InsightEngine.compareLast7vsPrev7(
                records: measurements,
                metric: metric,
                now: now,
                calendar: calendar
            ) else {
                continue
            }

            let insight = WeeklyInsight(
                id: UUID().uuidString,
                metric: metric.label,
                text: InsightEngine.makeText(result: r, metric: metric),
                last7Avg: r.last7Avg,
                prev7Avg: r.prev7Avg,
                delta: r.delta,
                percentChange: r.percentChange,
                direction: r.direction,
                createdAt: now,
                localOnly: true
            )

            results.append(insight)
        }

        return results
    }
}
