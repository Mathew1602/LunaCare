//
//  FakeMeasurementData.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-25.
//

import Foundation

struct FakeMeasurementData {

    static func generate30Days() -> [Measurement] {
        var records: [Measurement] = []
        let now = Date()

        for i in 0..<30 {
            let day = Calendar.current.date(byAdding: .day, value: -i, to: now)!

            let m = Measurement(
                id: UUID().uuidString,
                createdAt: day,
                sleepTrouble1to10: Double.random(in: 1...6), avgHeartRateBpm: Double.random(in: 60...90), restingHRBpm: Double.random(in: 55...75),
                walkingHeartRateAvgBpm: Double.random(in: 85...110),
                sleepHours: Double.random(in: 5.5...8.5),
                deepSleepHours: Double.random(in: 1.0...2.5),
                remSleepHours: Double.random(in: 0.8...2.0),
                coreSleepHours: Double.random(in: 3.0...4.0),
                sleepEfficiencyPct: Double.random(in: 85...97),
                wakeAfterSleepOnsetMin: Double.random(in: 10...35)
            )

            records.append(m)
        }

        return records.sorted { $0.createdAt < $1.createdAt }
    }
}
