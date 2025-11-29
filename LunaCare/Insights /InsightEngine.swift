//
//  InsightEngine.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-24.
//

struct InsightEngine {

    /// Compare last 7 records vs previous 7 records (rolling weeks).
    static func compareLast7vsPrev7(
        records: [Measurement],
        metric: InsightMetric
    ) -> InsightResult? {

        let sorted = records.sorted { $0.createdAt < $1.createdAt }
        guard sorted.count >= 14 else { return nil }

        let last14 = Array(sorted.suffix(14))
        let prev7 = Array(last14.prefix(7))
        let last7 = Array(last14.suffix(7))

        let prevValues = prev7.compactMap { metric.value(from: $0) }
        let lastValues = last7.compactMap { metric.value(from: $0) }

        guard !prevValues.isEmpty, !lastValues.isEmpty else { return nil }

        let prevAvg = prevValues.reduce(0, +) / Double(prevValues.count)
        let lastAvg = lastValues.reduce(0, +) / Double(lastValues.count)

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

    /// This will return a user-facing sentence
    static func makeText(records: [Measurement], metric: InsightMetric) -> String? {
        guard let r = compareLast7vsPrev7(records: records, metric: metric) else { return nil }

        let goodOrBad: String
        if r.direction == "about the same" {
            goodOrBad = "stable"
        } else {
            let improvement = (r.delta > 0 && metric.higherIsBetter) || (r.delta < 0 && !metric.higherIsBetter)
            goodOrBad = improvement ? "an improvement" : "a decline"
        }

        return String(
            format: "Your %@ is %@ vs last week (%0.2f → %0.2f, %+0.2f, %+0.1f%%) — %@.",
            metric.label, r.direction, r.prev7Avg, r.last7Avg, r.delta, r.percentChange, goodOrBad
        )
    }
}

// MARK: Example running the InsightEngine code below

//let fake30 = FakeStruct.highRisk30Days()
//

//if let text = InsightEngine.makeText(records: fake30, metric: .restingHR) {
//    print(text)
//}
//

//if let text = InsightEngine.makeText(records: fake30, metric: .sleepHours) {
//    print(text)
//}
//

//if let text = InsightEngine.makeText(records: fake30, metric: .sleepEfficiencyPct) {
//    print(text)
//}
