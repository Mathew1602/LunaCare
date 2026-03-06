//
//  InsightMetric+AllCases.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-25.
//

extension InsightMetric: CaseIterable {
    static var allCases: [InsightMetric] {
        return [
            // Heart
            .restingHR,
            .avgHR,
            .walkingHR,

            // Sleep
            .sleepHours,
            .deepSleepHours,
            .remSleepHours,
            .coreSleepHours,
            .sleepEfficiencyPct,
            .wakeAfterSleepOnsetMin,
            .sleepTroubleScore
        ]
    }
}
