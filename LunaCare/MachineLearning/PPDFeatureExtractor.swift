//
//  PPDFeatureExtractor.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-24.
//


import Foundation
import CoreML

final class PPDFeaturePipeline {

    // Suffixes used in training
    private let suffixes = ["mean", "std", "min", "max", "slope", "last"]

    private let X_COLUMNS: [String] = [
        "mood_1to5_mean","mood_1to5_std","mood_1to5_min","mood_1to5_max","mood_1to5_slope","mood_1to5_last",
        "bleeding_1to10_mean","bleeding_1to10_std","bleeding_1to10_min","bleeding_1to10_max","bleeding_1to10_slope","bleeding_1to10_last",
        "hair_loss_1to10_mean","hair_loss_1to10_std","hair_loss_1to10_min","hair_loss_1to10_max","hair_loss_1to10_slope","hair_loss_1to10_last",
        "appetite_issue_1to10_mean","appetite_issue_1to10_std","appetite_issue_1to10_min","appetite_issue_1to10_max","appetite_issue_1to10_slope","appetite_issue_1to10_last",
        "sleep_trouble_1to10_mean","sleep_trouble_1to10_std","sleep_trouble_1to10_min","sleep_trouble_1to10_max","sleep_trouble_1to10_slope","sleep_trouble_1to10_last",

        "sleep_hours_mean","sleep_hours_std","sleep_hours_min","sleep_hours_max","sleep_hours_slope","sleep_hours_last",
        "deep_sleep_hours_mean","deep_sleep_hours_std","deep_sleep_hours_min","deep_sleep_hours_max","deep_sleep_hours_slope","deep_sleep_hours_last",
        "rem_sleep_hours_mean","rem_sleep_hours_std","rem_sleep_hours_min","rem_sleep_hours_max","rem_sleep_hours_slope","rem_sleep_hours_last",
        "core_sleep_hours_mean","core_sleep_hours_std","core_sleep_hours_min","core_sleep_hours_max","core_sleep_hours_slope","core_sleep_hours_last",
        "sleep_efficiency_pct_mean","sleep_efficiency_pct_std","sleep_efficiency_pct_min","sleep_efficiency_pct_max","sleep_efficiency_pct_slope","sleep_efficiency_pct_last",
        "wake_after_sleep_onset_min_mean","wake_after_sleep_onset_min_std","wake_after_sleep_onset_min_min","wake_after_sleep_onset_min_max","wake_after_sleep_onset_min_slope","wake_after_sleep_onset_min_last",

        "avg_heart_rate_bpm_mean","avg_heart_rate_bpm_std","avg_heart_rate_bpm_min","avg_heart_rate_bpm_max","avg_heart_rate_bpm_slope","avg_heart_rate_bpm_last",
        "resting_heart_rate_bpm_mean","resting_heart_rate_bpm_std","resting_heart_rate_bpm_min","resting_heart_rate_bpm_max","resting_heart_rate_bpm_slope","resting_heart_rate_bpm_last",
        "walking_heart_rate_avg_bpm_mean","walking_heart_rate_avg_bpm_std","walking_heart_rate_avg_bpm_min","walking_heart_rate_avg_bpm_max","walking_heart_rate_avg_bpm_slope","walking_heart_rate_avg_bpm_last",
        "hrv_sdnn_ms_mean","hrv_sdnn_ms_std","hrv_sdnn_ms_min","hrv_sdnn_ms_max","hrv_sdnn_ms_slope","hrv_sdnn_ms_last",
        "respiratory_rate_bpm_mean","respiratory_rate_bpm_std","respiratory_rate_bpm_min","respiratory_rate_bpm_max","respiratory_rate_bpm_slope","respiratory_rate_bpm_last",
        "oxygen_saturation_pct_mean","oxygen_saturation_pct_std","oxygen_saturation_pct_min","oxygen_saturation_pct_max","oxygen_saturation_pct_slope","oxygen_saturation_pct_last",
        "vo2max_ml_kg_min_mean","vo2max_ml_kg_min_std","vo2max_ml_kg_min_min","vo2max_ml_kg_min_max","vo2max_ml_kg_min_slope","vo2max_ml_kg_min_last",

        "steps_mean","steps_std","steps_min","steps_max","steps_slope","steps_last",
        "distance_walked_km_mean","distance_walked_km_std","distance_walked_km_min","distance_walked_km_max","distance_walked_km_slope","distance_walked_km_last",
        "flights_climbed_mean","flights_climbed_std","flights_climbed_min","flights_climbed_max","flights_climbed_slope","flights_climbed_last",
        "active_energy_kcal_mean","active_energy_kcal_std","active_energy_kcal_min","active_energy_kcal_max","active_energy_kcal_slope","active_energy_kcal_last",
        "basal_energy_kcal_mean","basal_energy_kcal_std","basal_energy_kcal_min","basal_energy_kcal_max","basal_energy_kcal_slope","basal_energy_kcal_last",
        "exercise_minutes_mean","exercise_minutes_std","exercise_minutes_min","exercise_minutes_max","exercise_minutes_slope","exercise_minutes_last",
        "stand_hours_mean","stand_hours_std","stand_hours_min","stand_hours_max","stand_hours_slope","stand_hours_last",
        "sunlight_hours_mean","sunlight_hours_std","sunlight_hours_min","sunlight_hours_max","sunlight_hours_slope","sunlight_hours_last",
        "weight_kg_mean","weight_kg_std","weight_kg_min","weight_kg_max","weight_kg_slope","weight_kg_last"
    ]

    func makeFeatureVector(from records: [Measurement], missingValue: Double = 0) -> [String: MLFeatureValue] {

        let bases = extractBaseNames(from: X_COLUMNS)

        var out: [String: MLFeatureValue] = [:]
        out.reserveCapacity(X_COLUMNS.count)

        for base in bases {
            let series = values(for: base, from: records, missingValue: missingValue)
            let summary = summarize(series)

            out["\(base)_mean"]  = MLFeatureValue(double: summary.mean)
            out["\(base)_std"]   = MLFeatureValue(double: summary.std)
            out["\(base)_min"]   = MLFeatureValue(double: summary.min)
            out["\(base)_max"]   = MLFeatureValue(double: summary.max)
            out["\(base)_slope"] = MLFeatureValue(double: summary.slope)
            out["\(base)_last"]  = MLFeatureValue(double: summary.last)
        }

        for name in X_COLUMNS where out[name] == nil {
            out[name] = MLFeatureValue(double: missingValue)
        }

        return out
    }

    //Turn into MLDictionaryFeatureProvider
    func makeProvider(from records: [Measurement], missingValue: Double = 0) throws -> MLDictionaryFeatureProvider {
        let dict = makeFeatureVector(from: records, missingValue: missingValue)
        return try MLDictionaryFeatureProvider(dictionary: dict)
    }


    private func extractBaseNames(from cols: [String]) -> [String] {
        var set: Set<String> = []
        for col in cols {
            for suf in suffixes {
                if col.hasSuffix("_\(suf)") {
                    let base = col.replacingOccurrences(of: "_\(suf)", with: "")
                    set.insert(base)
                }
            }
        }
        return Array(set).sorted()
    }


    private func values(for base: String, from records: [Measurement], missingValue: Double) -> [Double] {

        let vals: [Double?] = records.map { m in
            switch base {
            // symptoms / mood
            case "mood_1to5": return m.mood1to5
            case "bleeding_1to10": return m.bleeding1to10
            case "hair_loss_1to10": return m.hairLoss1to10
            case "appetite_issue_1to10": return m.appetiteIssue1to10
            case "sleep_trouble_1to10": return m.sleepTrouble1to10

            // sleep
            case "sleep_hours": return m.sleepHours
            case "deep_sleep_hours": return m.deepSleepHours
            case "rem_sleep_hours": return m.remSleepHours
            case "core_sleep_hours": return m.coreSleepHours
            case "sleep_efficiency_pct": return m.sleepEfficiencyPct
            case "wake_after_sleep_onset_min": return m.wakeAfterSleepOnsetMin

            // heart
            case "avg_heart_rate_bpm": return m.avgHeartRateBpm
            case "resting_heart_rate_bpm": return m.restingHRBpm
            case "walking_heart_rate_avg_bpm": return m.walkingHeartRateAvgBpm
            case "hrv_sdnn_ms": return m.hrvSDNNms
            case "respiratory_rate_bpm": return m.respiratoryRateBpm
            case "oxygen_saturation_pct": return m.oxygenSaturationPct
            case "vo2max_ml_kg_min": return m.vo2Max

            // activity / body
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

        return vals.map { $0 ?? missingValue }
    }


    private struct Summary {
        let mean: Double
        let std: Double
        let min: Double
        let max: Double
        let slope: Double
        let last: Double
    }

    private func summarize(_ xs: [Double]) -> Summary {
        guard !xs.isEmpty else {
            return Summary(mean: 0, std: 0, min: 0, max: 0, slope: 0, last: 0)
        }

        let n = Double(xs.count)
        let mean = xs.reduce(0, +) / n
        let minV = xs.min() ?? 0
        let maxV = xs.max() ?? 0
        let lastV = xs.last ?? 0

        // sample std (ddof=1)
        let varSum = xs.reduce(0) { $0 + pow($1 - mean, 2) }
        let std = xs.count > 1 ? sqrt(varSum / (n - 1)) : 0

        let slope = linearSlope(xs)

        return Summary(mean: mean, std: std, min: minV, max: maxV, slope: slope, last: lastV)
    }

    private func linearSlope(_ ys: [Double]) -> Double {
        let count = ys.count
        guard count >= 2 else { return 0 }

        let n = Double(count)
        let xMean = (n - 1) / 2.0
        let yMean = ys.reduce(0, +) / n

        var num = 0.0
        var den = 0.0
        for (i, y) in ys.enumerated() {
            let x = Double(i)
            num += (x - xMean) * (y - yMean)
            den += (x - xMean) * (x - xMean)
        }

        return den == 0 ? 0 : num / den
    }
}
