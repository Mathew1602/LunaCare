//
//  InsightMetricENUM.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-24.
//

enum InsightMetric {
    // Heart
    case restingHR
    case avgHR
    case walkingHR
    case hrv
    case respiratoryRate
    case oxygenSaturation
    case vo2Max

    // Sleep
    case sleepHours
    case deepSleepHours
    case remSleepHours
    case coreSleepHours
    case sleepEfficiencyPct
    case wakeAfterSleepOnsetMin

    // Activity
    case steps
    case distanceWalked
    case flightsClimbed
    case activeEnergy
    case basalEnergy
    case exerciseMinutes
    case standHours

    // Mood, symptoms, and body measurements
    case mood
    case fatigue
    case bleeding
    case hairLoss
    case appetiteIssue
    case sleepTrouble
    case weight

    func value(from m: Measurement) -> Double? {
        switch self {
        // Heart
        case .restingHR: return m.restingHRBpm
        case .avgHR: return m.avgHeartRateBpm
        case .walkingHR: return m.walkingHeartRateAvgBpm
        case .hrv: return m.hrvSDNNms
        case .respiratoryRate: return m.respiratoryRateBpm
        case .oxygenSaturation: return m.oxygenSaturationPct
        case .vo2Max: return m.vo2Max

        // Sleep
        case .sleepHours: return m.sleepHours
        case .deepSleepHours: return m.deepSleepHours
        case .remSleepHours: return m.remSleepHours
        case .coreSleepHours: return m.coreSleepHours
        case .sleepEfficiencyPct: return m.sleepEfficiencyPct
        case .wakeAfterSleepOnsetMin: return m.wakeAfterSleepOnsetMin

        // Activity
        case .steps: return m.steps.map(Double.init)
        case .distanceWalked: return m.distanceWalkedKm
        case .flightsClimbed: return m.flightsClimbed
        case .activeEnergy: return m.activeEnergyKcal
        case .basalEnergy: return m.basalEnergyKcal
        case .exerciseMinutes: return m.exerciseMinutes
        case .standHours: return m.standHours

        // Mood, symptoms, and body measurements
        case .mood: return m.mood1to5
        case .fatigue: return m.fatigue1to10
        case .bleeding: return m.bleeding1to10
        case .hairLoss: return m.hairLoss1to10
        case .appetiteIssue: return m.appetiteIssue1to10
        case .sleepTrouble: return m.sleepTrouble1to10
        case .weight: return m.weightKg
        }
    }

    var label: String {
        switch self {
        // Heart
        case .restingHR: return "resting heart rate"
        case .avgHR: return "average heart rate"
        case .walkingHR: return "walking heart rate"
        case .hrv: return "heart rate variability"
        case .respiratoryRate: return "respiratory rate"
        case .oxygenSaturation: return "blood oxygen"
        case .vo2Max: return "VO2 max"

        // Sleep
        case .sleepHours: return "sleep hours"
        case .deepSleepHours: return "deep sleep hours"
        case .remSleepHours: return "REM sleep hours"
        case .coreSleepHours: return "core sleep hours"
        case .sleepEfficiencyPct: return "sleep efficiency"
        case .wakeAfterSleepOnsetMin: return "wake after sleep onset"

        // Activity
        case .steps: return "steps"
        case .distanceWalked: return "walking distance"
        case .flightsClimbed: return "flights climbed"
        case .activeEnergy: return "active energy"
        case .basalEnergy: return "basal energy"
        case .exerciseMinutes: return "exercise minutes"
        case .standHours: return "stand hours"

        // Mood, symptoms, and body measurements
        case .mood: return "mood score"
        case .fatigue: return "fatigue"
        case .bleeding: return "bleeding"
        case .hairLoss: return "hair loss"
        case .appetiteIssue: return "appetite issues"
        case .sleepTrouble: return "sleep trouble"
        case .weight: return "weight"
        }
    }

    /// Used to decide if “higher” is good or bad for wording
    var higherIsBetter: Bool? {
        switch self {
        case .sleepHours, .deepSleepHours, .remSleepHours, .coreSleepHours,
             .sleepEfficiencyPct, .steps, .distanceWalked, .flightsClimbed,
             .activeEnergy, .exerciseMinutes, .standHours, .mood, .hrv, .vo2Max:
            return true
        case .wakeAfterSleepOnsetMin, .fatigue, .bleeding, .hairLoss,
             .appetiteIssue, .sleepTrouble:
            return false
        case .weight, .restingHR, .avgHR, .walkingHR, .respiratoryRate,
             .oxygenSaturation, .basalEnergy:
            return nil
        }
    }

    /// Optional: threshold for "about the same"
    var neutralDeltaThreshold: Double {
        switch self {
        case .sleepHours, .deepSleepHours, .remSleepHours, .coreSleepHours:
            return 0.25        // 15 minutes
        case .sleepEfficiencyPct:
            return 1.0         // 1%
        case .wakeAfterSleepOnsetMin:
            return 2.0         // 2 minutes
        case .steps:
            return 500
        case .distanceWalked:
            return 0.5
        case .flightsClimbed:
            return 1
        case .activeEnergy, .basalEnergy:
            return 50
        case .exerciseMinutes:
            return 5
        case .standHours:
            return 0.5
        case .mood, .fatigue, .bleeding, .hairLoss, .appetiteIssue, .sleepTrouble:
            return 0.5
        case .hrv:
            return 3
        case .respiratoryRate, .vo2Max:
            return 0.5
        case .oxygenSaturation:
            return 0.5
        case .weight:
            return 0.2
        default:
            return 0.5         // default bpm-ish threshold
        }
    }
}
