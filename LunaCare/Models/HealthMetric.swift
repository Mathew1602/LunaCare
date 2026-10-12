//
//  HealthMetric.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-09-27.
//

import Foundation

enum HealthMetric: String, CaseIterable, Identifiable, Codable {
    case sleep, deepSleep, remSleep, coreSleep, sleepEfficiency, awakeAfterSleep
    case steps, distance, flights, activeEnergy, basalEnergy, exercise, stand
    case avgHeartRate, restingHR, walkingHR, hrv, respiratoryRate, bloodOxygen, vo2Max
    case weight

    var id: String { rawValue }

    static let defaults: [HealthMetric] = [.sleep, .activeEnergy, .restingHR]
    static let maxSelected = 6
    static let categories = ["Sleep", "Activity", "Heart", "Body"]

    var title: String {
        switch self {
        case .sleep: return "Sleep"
        case .deepSleep: return "Deep Sleep"
        case .remSleep: return "REM Sleep"
        case .coreSleep: return "Core Sleep"
        case .sleepEfficiency: return "Sleep Eff."
        case .awakeAfterSleep: return "Awake"
        case .steps: return "Steps"
        case .distance: return "Distance"
        case .flights: return "Flights"
        case .activeEnergy: return "Active Energy"
        case .basalEnergy: return "Resting Energy"
        case .exercise: return "Exercise"
        case .stand: return "Stand"
        case .avgHeartRate: return "Avg HR"
        case .restingHR: return "Resting HR"
        case .walkingHR: return "Walking HR"
        case .hrv: return "HRV"
        case .respiratoryRate: return "Resp. Rate"
        case .bloodOxygen: return "Blood O₂"
        case .vo2Max: return "VO₂ Max"
        case .weight: return "Weight"
        }
    }

    var icon: String {
        switch self {
        case .sleep: return "moon"
        case .deepSleep: return "bed.double"
        case .remSleep: return "powersleep"
        case .coreSleep: return "zzz"
        case .sleepEfficiency: return "moon.stars"
        case .awakeAfterSleep: return "alarm"
        case .steps: return "figure.walk"
        case .distance: return "map"
        case .flights: return "stairs"
        case .activeEnergy: return "waveform.path.ecg"
        case .basalEnergy: return "flame"
        case .exercise: return "figure.run"
        case .stand: return "figure.stand"
        case .avgHeartRate: return "heart.fill"
        case .restingHR: return "heart"
        case .walkingHR: return "arrow.up.heart"
        case .hrv: return "waveform.path"
        case .respiratoryRate: return "lungs"
        case .bloodOxygen: return "drop"
        case .vo2Max: return "figure.run.circle"
        case .weight: return "scalemass"
        }
    }

    var category: String {
        switch self {
        case .sleep, .deepSleep, .remSleep, .coreSleep, .sleepEfficiency, .awakeAfterSleep:
            return "Sleep"
        case .steps, .distance, .flights, .activeEnergy, .basalEnergy, .exercise, .stand:
            return "Activity"
        case .avgHeartRate, .restingHR, .walkingHR, .hrv, .respiratoryRate, .bloodOxygen, .vo2Max:
            return "Heart"
        case .weight:
            return "Body"
        }
    }

    private static let stepsFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    func formattedValue(from m: Measurement?) -> String {
        guard let m else { return "--" }
        switch self {
        case .sleep: return hours(m.sleepHours)
        case .deepSleep: return hours(m.deepSleepHours)
        case .remSleep: return hours(m.remSleepHours)
        case .coreSleep: return hours(m.coreSleepHours)
        case .sleepEfficiency: return format(m.sleepEfficiencyPct, "%.0f%%")
        case .awakeAfterSleep: return int(m.wakeAfterSleepOnsetMin, "min")
        case .steps:
            guard let v = m.steps else { return "--" }
            return Self.stepsFormatter.string(from: NSNumber(value: v)) ?? "\(v)"
        case .distance: return format(m.distanceWalkedKm, "%.1f km")
        case .flights:
            guard let v = m.flightsClimbed else { return "--" }
            return "\(Int(v))"
        case .activeEnergy: return int(m.activeEnergyKcal, "cal")
        case .basalEnergy: return int(m.basalEnergyKcal, "cal")
        case .exercise: return int(m.exerciseMinutes, "min")
        case .stand: return format(m.standHours, "%.0f hrs")
        case .avgHeartRate: return int(m.avgHeartRateBpm, "bpm")
        case .restingHR: return int(m.restingHRBpm, "bpm")
        case .walkingHR: return int(m.walkingHeartRateAvgBpm, "bpm")
        case .hrv: return int(m.hrvSDNNms, "ms")
        case .respiratoryRate: return format(m.respiratoryRateBpm, "%.0f br/min")
        case .bloodOxygen: return format(m.oxygenSaturationPct.map { $0 * 100 }, "%.0f%%")
        case .vo2Max: return format(m.vo2Max, "%.1f")
        case .weight: return format(m.weightKg, "%.1f kg")
        }
    }

    private func hours(_ v: Double?) -> String {
        format(v, "%.1f hrs")
    }

    private func int(_ v: Double?, _ unit: String) -> String {
        guard let v else { return "--" }
        return "\(Int(v)) \(unit)"
    }

    private func format(_ v: Double?, _ fmt: String) -> String {
        guard let v else { return "--" }
        return String(format: fmt, v)
    }
}
