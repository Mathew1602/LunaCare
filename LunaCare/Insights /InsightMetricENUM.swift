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

    // Sleep
    case sleepHours
    case deepSleepHours
    case remSleepHours
    case coreSleepHours
    case sleepEfficiencyPct
    case wakeAfterSleepOnsetMin
    case sleepTroubleScore

    func value(from m: Measurement) -> Double? {
        switch self {
        // Heart
        case .restingHR: return m.restingHRBpm
        case .avgHR: return m.avgHeartRateBpm
        case .walkingHR: return m.walkingHeartRateAvgBpm

        // Sleep
        case .sleepHours: return m.sleepHours
        case .deepSleepHours: return m.deepSleepHours
        case .remSleepHours: return m.remSleepHours
        case .coreSleepHours: return m.coreSleepHours
        case .sleepEfficiencyPct: return m.sleepEfficiencyPct
        case .wakeAfterSleepOnsetMin: return m.wakeAfterSleepOnsetMin
        case .sleepTroubleScore: return m.sleepTrouble1to10
        }
    }

    var label: String {
        switch self {
        // Heart
        case .restingHR: return "resting heart rate"
        case .avgHR: return "average heart rate"
        case .walkingHR: return "walking heart rate"

        // Sleep
        case .sleepHours: return "sleep hours"
        case .deepSleepHours: return "deep sleep hours"
        case .remSleepHours: return "REM sleep hours"
        case .coreSleepHours: return "core sleep hours"
        case .sleepEfficiencyPct: return "sleep efficiency"
        case .wakeAfterSleepOnsetMin: return "wake after sleep onset"
        case .sleepTroubleScore: return "sleep trouble score"
        }
    }

    /// Used to decide if “higher” is good or bad for wording
    var higherIsBetter: Bool {
        switch self {
        case .sleepHours, .deepSleepHours, .remSleepHours, .coreSleepHours, .sleepEfficiencyPct:
            return true
        case .wakeAfterSleepOnsetMin, .sleepTroubleScore, .restingHR, .avgHR, .walkingHR:
            return false
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
        default:
            return 0.5         // default bpm-ish threshold
        }
    }
}
