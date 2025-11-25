//
//  testDataML.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-24.
//

import Foundation

struct FakeStruct {

    /// 30 deterministic days of high / semi-high risk Measurements
    static func highRisk30Days(
        startDate: Date = DateComponents(calendar: .current, year: 2025, month: 2, day: 1).date!,
        days: Int = 30
    ) -> [Measurement] {

        let cal = Calendar.current
        return (0..<days).map { i in
            let date = cal.date(byAdding: .day, value: i, to: startDate)!

            // Deterministic patterns (match Python style)
            let mood1to5 = clamp(2.6 - (0.8 * Double(i) / Double(days - 1)), 1, 5)
            let sleepTrouble = clamp(6.8 + (1.4 * Double(i) / Double(days - 1)), 1, 10)
            let restingHR = 72.0 + (10.0 * Double(i) / Double(days - 1))
            let steps = Int(clamp(3000.0 - (1000.0 * Double(i) / Double(days - 1)), 0, 20000))
            let sunlight = clamp(0.3 - (0.2 * Double(i) / Double(days - 1)), 0, 24)

            return Measurement(
                id: nil,
                createdAt: date,

                // symptoms / mood
                mood1to5: mood1to5,
                bleeding1to10: 2,
                hairLoss1to10: 1,
                appetiteIssue1to10: 6,
                sleepTrouble1to10: sleepTrouble,

                // movement
                steps: steps,
                distanceWalkedKm: 2.0,
                flightsClimbed: 1,
                activeEnergyKcal: 200,
                basalEnergyKcal: 1400,
                exerciseMinutes: 5,
                standHours: 6,
                sunlightHours: sunlight,

                // heart
                avgHeartRateBpm: 85,
                restingHRBpm: restingHR,
                walkingHeartRateAvgBpm: 100,
                hrvSDNNms: 35,
                respiratoryRateBpm: 16,
                oxygenSaturationPct: 98,
                vo2Max: 30,

                // sleep
                sleepHours: 6.5,
                deepSleepHours: 1.0,
                remSleepHours: 1.5,
                coreSleepHours: 4.0,
                sleepEfficiencyPct: 80,
                wakeAfterSleepOnsetMin: 30,

                // body
                weightKg: 68,

                source: "fake_high_risk"
            )
        }
    }

    private static func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(x, lo), hi)
    }
}
