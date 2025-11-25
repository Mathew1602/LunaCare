//
//  MeasurementRepository.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation

final class MeasurementRepository {

    func upsert(uid: String, measurement: Measurement, completion: ((Error?) -> Void)? = nil) {

        var data: [String: Any] = [
            "createdAt": measurement.createdAt,
            "source": measurement.source as Any,
            "updatedAt": Date()
        ]

        // Symptom / mood
        if let v = measurement.mood1to5 { data["mood1to5"] = v }
        if let v = measurement.bleeding1to10 { data["bleeding1to10"] = v }
        if let v = measurement.hairLoss1to10 { data["hairLoss1to10"] = v }
        if let v = measurement.appetiteIssue1to10 { data["appetiteIssue1to10"] = v }
        if let v = measurement.sleepTrouble1to10 { data["sleepTrouble1to10"] = v }

        // Activity / movement
        if let v = measurement.steps { data["steps"] = v }
        if let v = measurement.distanceWalkedKm { data["distanceWalkedKm"] = v }
        if let v = measurement.flightsClimbed { data["flightsClimbed"] = v }
        if let v = measurement.activeEnergyKcal { data["activeEnergyKcal"] = v }
        if let v = measurement.basalEnergyKcal { data["basalEnergyKcal"] = v }
        if let v = measurement.exerciseMinutes { data["exerciseMinutes"] = v }
        if let v = measurement.standHours { data["standHours"] = v }
        if let v = measurement.sunlightHours { data["sunlightHours"] = v }

        // Heart / cardio
        if let v = measurement.avgHeartRateBpm { data["avgHeartRateBpm"] = v }
        if let v = measurement.restingHRBpm { data["restingHRBpm"] = v }
        if let v = measurement.walkingHeartRateAvgBpm { data["walkingHeartRateAvgBpm"] = v }
        if let v = measurement.hrvSDNNms { data["hrvSDNNms"] = v }
        if let v = measurement.respiratoryRateBpm { data["respiratoryRateBpm"] = v }
        if let v = measurement.oxygenSaturationPct { data["oxygenSaturationPct"] = v }
        if let v = measurement.vo2Max { data["vo2Max"] = v }

        // Sleep
        if let v = measurement.sleepHours { data["sleepHours"] = v }
        if let v = measurement.deepSleepHours { data["deepSleepHours"] = v }
        if let v = measurement.remSleepHours { data["remSleepHours"] = v }
        if let v = measurement.coreSleepHours { data["coreSleepHours"] = v }
        if let v = measurement.sleepEfficiencyPct { data["sleepEfficiencyPct"] = v }
        if let v = measurement.wakeAfterSleepOnsetMin { data["wakeAfterSleepOnsetMin"] = v }

        // Body
        if let v = measurement.weightKg { data["weightKg"] = v }

        let docId = measurement.id ?? UUID().uuidString
        let path = FSPath.measurements(uid) + "/\(docId)"
        FirestoreManager.shared.write(path: path, data: data, merge: true, completion: completion)
    }
}

