//
//  PPDFeatureExtractor.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-24.
//  Edit by Fernanda

import Foundation
import CoreML

final class PPDFeaturePipeline {

    static let windowDays = 30
    static let featureSchemaVersion = 1
    static let suffixes = ["mean", "std", "min", "max", "slope", "last"]

    // Same order as training (federated-learning/functions-ml/features.py BASE_FEATURES)
    static let bases: [String] = [
        "fatigue_1to10",
        "mood_1to5",
        "bleeding_1to10",
        "hair_loss_1to10",
        "appetite_issue_1to10",
        "sleep_trouble_1to10",
        "sleep_hours",
        "deep_sleep_hours",
        "rem_sleep_hours",
        "core_sleep_hours",
        "sleep_efficiency_pct",
        "wake_after_sleep_onset_min",
        "avg_heart_rate_bpm",
        "resting_heart_rate_bpm",
        "walking_heart_rate_avg_bpm",
        "hrv_sdnn_ms",
        "respiratory_rate_bpm",
        "oxygen_saturation_pct",
        "vo2max_ml_kg_min",
        "steps",
        "distance_walked_km",
        "flights_climbed",
        "active_energy_kcal",
        "basal_energy_kcal",
        "exercise_minutes",
        "stand_hours",
        "sunlight_hours",
        "weight_kg"
    ]

    static let featureNames: [String] = bases.flatMap { base in suffixes.map { "\(base)_\($0)" } }

    /// 168 features; nil = missing (uploaded as null, fed to Core ML as NaN).
    func rawFeatures(from records: [Measurement], windowEnd: Date = Date()) -> [String: Double?] {
        let days = dailySlots(records, windowEnd: windowEnd)
        var out: [String: Double?] = [:]
        out.reserveCapacity(Self.featureNames.count)

        for base in Self.bases {
            let s = summarize(days.map { day in day.flatMap { Self.value(base, in: $0) } })
            out.updateValue(s.mean, forKey: "\(base)_mean")
            out.updateValue(s.std, forKey: "\(base)_std")
            out.updateValue(s.min, forKey: "\(base)_min")
            out.updateValue(s.max, forKey: "\(base)_max")
            out.updateValue(s.slope, forKey: "\(base)_slope")
            out.updateValue(s.last, forKey: "\(base)_last")
        }
        return out
    }

    func makeFeatureVector(from records: [Measurement], windowEnd: Date = Date()) -> [String: MLFeatureValue] {
        rawFeatures(from: records, windowEnd: windowEnd).mapValues { MLFeatureValue(double: $0 ?? .nan) }
    }

    func makeProvider(from records: [Measurement], windowEnd: Date = Date()) throws -> MLDictionaryFeatureProvider {
        try MLDictionaryFeatureProvider(dictionary: makeFeatureVector(from: records, windowEnd: windowEnd))
    }

    func daysWithData(_ records: [Measurement], windowEnd: Date = Date()) -> Int {
        dailySlots(records, windowEnd: windowEnd).compactMap { $0 }.count
    }

    /// One slot per calendar day, oldest first, ending on windowEnd's day. Latest record per day wins.
    func dailySlots(_ records: [Measurement], windowEnd: Date) -> [Measurement?] {
        let cal = Calendar.current
        let end = cal.startOfDay(for: windowEnd)
        var slots = [Measurement?](repeating: nil, count: Self.windowDays)

        for m in records.sorted(by: { $0.createdAt < $1.createdAt }) {
            guard let back = cal.dateComponents([.day], from: cal.startOfDay(for: m.createdAt), to: end).day,
                  back >= 0, back < Self.windowDays else { continue }
            slots[Self.windowDays - 1 - back] = m
        }
        return slots
    }

    static func value(_ base: String, in m: Measurement) -> Double? {
        switch base {
        case "fatigue_1to10": return m.fatigue1to10
        case "mood_1to5": return m.mood1to5
        case "bleeding_1to10": return m.bleeding1to10
        case "hair_loss_1to10": return m.hairLoss1to10
        case "appetite_issue_1to10": return m.appetiteIssue1to10
        case "sleep_trouble_1to10": return m.sleepTrouble1to10
        case "sleep_hours": return m.sleepHours
        case "deep_sleep_hours": return m.deepSleepHours
        case "rem_sleep_hours": return m.remSleepHours
        case "core_sleep_hours": return m.coreSleepHours
        case "sleep_efficiency_pct": return m.sleepEfficiencyPct
        case "wake_after_sleep_onset_min": return m.wakeAfterSleepOnsetMin
        case "avg_heart_rate_bpm": return m.avgHeartRateBpm
        case "resting_heart_rate_bpm": return m.restingHRBpm
        case "walking_heart_rate_avg_bpm": return m.walkingHeartRateAvgBpm
        case "hrv_sdnn_ms": return m.hrvSDNNms
        case "respiratory_rate_bpm": return m.respiratoryRateBpm
        case "oxygen_saturation_pct": return m.oxygenSaturationPct
        case "vo2max_ml_kg_min": return m.vo2Max
        case "steps": return m.steps.map(Double.init)
        case "distance_walked_km": return m.distanceWalkedKm
        case "flights_climbed": return m.flightsClimbed
        case "active_energy_kcal": return m.activeEnergyKcal
        case "basal_energy_kcal": return m.basalEnergyKcal
        case "exercise_minutes": return m.exerciseMinutes
        case "stand_hours": return m.standHours
        case "sunlight_hours": return m.sunlightHours
        case "weight_kg": return m.weightKg
        default: return nil
        }
    }

    private struct Summary {
        var mean: Double?
        var std: Double?
        var min: Double?
        var max: Double?
        var slope: Double?
        var last: Double?
    }

    // Matches pandas (NaN-skipping, sample std) and np.polyfit over day positions with values.
    private func summarize(_ ys: [Double?]) -> Summary {
        let points = ys.enumerated().compactMap { i, y -> (x: Double, y: Double)? in
            guard let y, !y.isNaN else { return nil }
            return (Double(i), y)
        }
        guard !points.isEmpty else { return Summary() }

        let values = points.map(\.y)
        let n = Double(points.count)
        let mean = values.reduce(0, +) / n
        var summary = Summary(mean: mean, min: values.min(), max: values.max(), last: values.last)

        if points.count >= 2 {
            summary.std = sqrt(values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / (n - 1))

            let xMean = points.reduce(0) { $0 + $1.x } / n
            var num = 0.0
            var den = 0.0
            for p in points {
                num += (p.x - xMean) * (p.y - mean)
                den += (p.x - xMean) * (p.x - xMean)
            }
            summary.slope = num / den
        }
        return summary
    }
}
