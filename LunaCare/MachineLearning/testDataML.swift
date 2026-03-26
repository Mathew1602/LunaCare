//
//  testDataML.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-24.
//  Updated for extreme high-risk profile with fatigue_1to10
//

import Foundation

struct FakeStruct {
    /// 30 deterministic days of extreme high-risk Measurements
    static func extremeHighRisk30Days(
        startDate: Date = DateComponents(calendar: .current, year: 2025, month: 2, day: 1).date!,
        days: Int = 30
    ) -> [Measurement] {

        let cal = Calendar.current
        return (0..<days).map { i in
            let date = cal.date(byAdding: .day, value: i, to: startDate)!

            // Deterministic extreme high-risk patterns
            let mood1to5 = clamp(1.5 + 0.2 * Double(i)/Double(days-1), 1, 2.5) // very low mood
            let fatigue1to10 = clamp(7.5 + 2.0 * Double(i)/Double(days-1), 7.5, 10) // very high fatigue
            let sleepTrouble = clamp(7.5 + 2.0 * Double(i)/Double(days-1), 7.5, 10) // high sleep trouble
            let restingHR = 75.0 + (12.0 * Double(i) / Double(days - 1)) // rising HR
            let steps = Int(clamp(1500.0 - (500.0 * Double(i) / Double(days - 1)), 0, 3000)) // very low activity
            let sunlight = clamp(0.1 - (0.05 * Double(i)/Double(days-1)), 0, 0.5) // almost no sunlight

            return Measurement(
                id: nil,
                createdAt: date,

                // symptoms / mood
                mood1to5: mood1to5,
                bleeding1to10: 3,
                hairLoss1to10: 2,
                appetiteIssue1to10: 7,
                sleepTrouble1to10: sleepTrouble,
                fatigue1to10: fatigue1to10,

                // movement
                steps: steps,
                distanceWalkedKm: clamp(0.5 + 0.1 * Double(i)/Double(days-1), 0.5, 1.5),
                flightsClimbed: Double(clamp(0.5, 0, 2)),
                activeEnergyKcal: clamp(100 + 20 * Double(i)/Double(days-1), 100, 200),
                basalEnergyKcal: 1400,
                exerciseMinutes: clamp(2 + Double(i)/Double(days-1), 2, 5),
                standHours: clamp(4 + Double(i)/Double(days-1), 4, 6),
                sunlightHours: sunlight,

                // heart
                avgHeartRateBpm: 85 + Double(i)/Double(days-1) * 5,
                restingHRBpm: restingHR,
                walkingHeartRateAvgBpm: 100 + Double(i)/Double(days-1) * 5,
                hrvSDNNms: clamp(25 - Double(i)/Double(days-1)*5, 20, 25),
                respiratoryRateBpm: 16 + Double(i)/Double(days-1),
                oxygenSaturationPct: 97,
                vo2Max: clamp(25 + Double(i)/Double(days-1), 25, 30),

                // sleep
                sleepHours: clamp(5.5 - Double(i)/Double(days-1)*0.5, 5, 6),
                deepSleepHours: clamp(0.8 - Double(i)/Double(days-1)*0.3, 0.5, 1.0),
                remSleepHours: clamp(1.0 - Double(i)/Double(days-1)*0.3, 0.7, 1.0),
                coreSleepHours: clamp(3.0 - Double(i)/Double(days-1)*0.5, 2.5, 3.0),
                sleepEfficiencyPct: clamp(70 - Double(i)/Double(days-1)*5, 65, 70),
                wakeAfterSleepOnsetMin: clamp(40 + Double(i)/Double(days-1)*20, 40, 60),

                // body
                weightKg: 68 - Double(i)/Double(days-1)*2,

                source: "fake_extreme_high_risk"
            )
        }
    }

    private static func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(x, lo), hi)
    }
}
