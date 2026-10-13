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
            .hrv,
            .respiratoryRate,
            .oxygenSaturation,
            .vo2Max,

            // Sleep
            .sleepHours,
            .deepSleepHours,
            .remSleepHours,
            .coreSleepHours,
            .sleepEfficiencyPct,
            .wakeAfterSleepOnsetMin,

            // Activity
            .steps,
            .distanceWalked,
            .flightsClimbed,
            .activeEnergy,
            .basalEnergy,
            .exerciseMinutes,
            .standHours,

            // Mood, symptoms, and body measurements
            .mood,
            .fatigue,
            .bleeding,
            .hairLoss,
            .appetiteIssue,
            .sleepTrouble,
            .weight
        ]
    }
}
