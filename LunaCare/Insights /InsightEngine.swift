//
//  InsightEngine.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-24.
//


import Foundation

struct InsightEngine {

    /// Compare the last 7 complete calendar days with the 7 days before them.
    static func compareLast7vsPrev7(
        records: [Measurement],
        metric: InsightMetric,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> InsightResult? {
        let today = calendar.startOfDay(for: now)
        guard
            let previousStart = calendar.date(byAdding: .day, value: -14, to: today),
            let recentStart = calendar.date(byAdding: .day, value: -7, to: today)
        else {
            return nil
        }

        let previousValues = dailyValues(
            in: records,
            metric: metric,
            from: previousStart,
            to: recentStart,
            calendar: calendar
        )
        let recentValues = dailyValues(
            in: records,
            metric: metric,
            from: recentStart,
            to: today,
            calendar: calendar
        )

        guard previousValues.count >= 5, recentValues.count >= 5 else { return nil }

        let prevAvg = previousValues.reduce(0, +) / Double(previousValues.count)
        let lastAvg = recentValues.reduce(0, +) / Double(recentValues.count)

        let delta = lastAvg - prevAvg
        let pct = prevAvg != 0 ? (delta / prevAvg) * 100.0 : 0

        let direction: String
        if abs(delta) < metric.neutralDeltaThreshold {
            direction = "about the same"
        } else if delta > 0 {
            direction = "higher"
        } else {
            direction = "lower"
        }

        return InsightResult(
            last7Avg: lastAvg,
            prev7Avg: prevAvg,
            delta: delta,
            percentChange: pct,
            direction: direction
        )
    }

    private static func dailyValues(
        in records: [Measurement],
        metric: InsightMetric,
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) -> [Double] {
        let valuesByDay = records.reduce(into: [Date: [Double]]()) { result, record in
            guard record.createdAt >= start, record.createdAt < end,
                  let value = metric.value(from: record),
                  value.isFinite
            else {
                return
            }
            let day = calendar.startOfDay(for: record.createdAt)
            result[day, default: []].append(value)
        }

        return valuesByDay.values.map { values in
            values.reduce(0, +) / Double(values.count)
        }
    }

    /// Generates a human-readable insight sentence from a weekly comparison.
    static func makeText(result r: InsightResult, metric: InsightMetric) -> String {
        let goodOrBad: String
        if r.direction == "about the same" {
            goodOrBad = "stable"
        } else if let higherIsBetter = metric.higherIsBetter {
            let improvement = (r.delta > 0 && higherIsBetter) || (r.delta < 0 && !higherIsBetter)
            goodOrBad = improvement ? "an improvement" : "a decline"
        } else {
            goodOrBad = "a change"
        }

        return String(
            format: "Your %@ is %@ vs last week (%0.2f → %0.2f, %+0.2f, %+0.1f%%) — %@.",
            metric.label, r.direction, r.prev7Avg, r.last7Avg, r.delta, r.percentChange, goodOrBad
        )
    }
}
