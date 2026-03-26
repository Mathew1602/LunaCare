//
//  MeasurementRepository.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation
import FirebaseFirestore

final class MeasurementRepository {

    // Formatter for YYYY-MM-DD doc IDs
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func dayId(for date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    // MARK: - Public

    /// Upload many measurements in batches.
    /// - Collapses multiple measurements per day into ONE (latest by createdAt).
    /// - One doc per day (yyyy-MM-dd). Overwrites each day doc.
    /// - Returns number of day-documents written.
    func upsertMany(uid: String, measurements: [Measurement]) async throws -> Int {

        let cal = Calendar.current
        let db = Firestore.firestore()
        let colRef = db.collection("users")
            .document(uid)
            .collection("measurements")

        // 1) Collapse to latest per day
        let latestPerDay: [Date: Measurement] = measurements.reduce(into: [:]) { acc, m in
            let dayStart = cal.startOfDay(for: m.createdAt)
            if let existing = acc[dayStart] {
                // keep the later one
                if m.createdAt > existing.createdAt {
                    acc[dayStart] = m
                }
            } else {
                acc[dayStart] = m
            }
        }

        let uniqueDays = latestPerDay.keys.sorted()
        let dayMeasurements = uniqueDays.compactMap { latestPerDay[$0] }

        // 2) Firestore batches max 500 writes
        var written = 0
        var index = 0

        while index < dayMeasurements.count {
            let chunk = Array(dayMeasurements[index..<min(index + 500, dayMeasurements.count)])
            let batch = db.batch()

            for m in chunk {
                let dayStart = cal.startOfDay(for: m.createdAt)
                let docId = m.id ?? dayId(for: dayStart)
                let docRef = colRef.document(docId)

                let data = firestoreData(for: m, dayStart: dayStart)

                // overwrite whole doc for that day
                batch.setData(data, forDocument: docRef, merge: true)
            }

            try await batch.commit()
            written += chunk.count
            index += 500
        }

        return written
    }

    /// Upsert **one daily rollup** measurement.
    /// Always overwrites that day’s doc.
    func upsert(uid: String, measurement: Measurement, completion: ((Error?) -> Void)? = nil) {

        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: measurement.createdAt)

        let data = firestoreData(for: measurement, dayStart: dayStart)

        let docId = measurement.id ?? dayId(for: dayStart)
        let path = FSPath.measurements(uid) + "/\(docId)"

        // overwrite = merge false
        FirestoreManager.shared.write(path: path, data: data, merge: true, completion: completion)
    }

    // MARK: - Helpers

    private func firestoreData(for m: Measurement, dayStart: Date) -> [String: Any] {
        var data: [String: Any] = [
            "createdAt": dayStart,
            "updatedAt": FieldValue.serverTimestamp(),
        ]

        if let s = m.source, !s.isEmpty { data["source"] = s }

        // Symptom / mood
        if let v = m.mood1to5 { data["mood1to5"] = v }
        if let v = m.bleeding1to10 { data["bleeding1to10"] = v }
        if let v = m.hairLoss1to10 { data["hairLoss1to10"] = v }
        if let v = m.appetiteIssue1to10 { data["appetiteIssue1to10"] = v }
        if let v = m.sleepTrouble1to10 { data["sleepTrouble1to10"] = v }

        // Activity
        if let v = m.steps { data["steps"] = v }
        if let v = m.distanceWalkedKm { data["distanceWalkedKm"] = v }
        if let v = m.flightsClimbed { data["flightsClimbed"] = v }
        if let v = m.activeEnergyKcal { data["activeEnergyKcal"] = v }
        if let v = m.basalEnergyKcal { data["basalEnergyKcal"] = v }
        if let v = m.exerciseMinutes { data["exerciseMinutes"] = v }
        if let v = m.standHours { data["standHours"] = v }
        if let v = m.sunlightHours { data["sunlightHours"] = v }

        // Heart
        if let v = m.avgHeartRateBpm { data["avgHeartRateBpm"] = v }
        if let v = m.restingHRBpm { data["restingHRBpm"] = v }
        if let v = m.walkingHeartRateAvgBpm { data["walkingHeartRateAvgBpm"] = v }
        if let v = m.hrvSDNNms { data["hrvSDNNms"] = v }
        if let v = m.respiratoryRateBpm { data["respiratoryRateBpm"] = v }
        if let v = m.oxygenSaturationPct { data["oxygenSaturationPct"] = v }
        if let v = m.vo2Max { data["vo2Max"] = v }

        // Sleep
        if let v = m.sleepHours { data["sleepHours"] = v }
        if let v = m.deepSleepHours { data["deepSleepHours"] = v }
        if let v = m.remSleepHours { data["remSleepHours"] = v }
        if let v = m.coreSleepHours { data["coreSleepHours"] = v }
        if let v = m.sleepEfficiencyPct { data["sleepEfficiencyPct"] = v } 
        if let v = m.wakeAfterSleepOnsetMin { data["wakeAfterSleepOnsetMin"] = v }

        // Body
        if let v = m.weightKg { data["weightKg"] = v }

        return data
    }


    func fetchRange(
        uid: String,
        from: Date,
        to: Date
    ) async throws -> [Measurement] {

        let query = Firestore.firestore()
            .collection("users").document(uid)
            .collection("measurements")
            .whereField("createdAt", isGreaterThanOrEqualTo: from)
            .whereField("createdAt", isLessThanOrEqualTo: to)
            .order(by: "createdAt", descending: false)

        let snap = try await query.getDocuments()
        return snap.documents.compactMap { Self.decodeMeasurement($0) }
    }

    /// Fetch rolling last N days, sorted oldest -> newest.
    func fetchLastDays(
        uid: String,
        lastDays: Int
    ) async throws -> [Measurement] {

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let from = cal.date(byAdding: .day, value: -(lastDays - 1), to: todayStart)!
        let to = Date()

        return try await fetchRange(uid: uid, from: from, to: to)
    }


    private static func decodeMeasurement(_ doc: QueryDocumentSnapshot) -> Measurement? {
        let d = doc.data()

        // createdAt required
        let createdAt: Date
        if let ts = d["createdAt"] as? Timestamp {
            createdAt = ts.dateValue()
        } else if let date = d["createdAt"] as? Date {
            createdAt = date
        } else {
            return nil
        }

        func intVal(_ key: String) -> Int? {
            if let v = d[key] as? Int { return v }
            if let v = d[key] as? Int64 { return Int(v) }
            if let v = d[key] as? Double { return Int(v) }
            return nil
        }

        func dblVal(_ key: String) -> Double? {
            if let v = d[key] as? Double { return v }
            if let v = d[key] as? Int { return Double(v) }
            if let v = d[key] as? Int64 { return Double(v) }
            return nil
        }

        return Measurement(
            id: doc.documentID,
            createdAt: createdAt,

            mood1to5: dblVal("mood1to5"),
            bleeding1to10: dblVal("bleeding1to10"),
            hairLoss1to10: dblVal("hairLoss1to10"),
            appetiteIssue1to10: dblVal("appetiteIssue1to10"),
            sleepTrouble1to10: dblVal("sleepTrouble1to10"),

            steps: intVal("steps"),
            distanceWalkedKm: dblVal("distanceWalkedKm"),
            flightsClimbed: dblVal("flightsClimbed"),
            activeEnergyKcal: dblVal("activeEnergyKcal"),
            basalEnergyKcal: dblVal("basalEnergyKcal"),
            exerciseMinutes: dblVal("exerciseMinutes"),
            standHours: dblVal("standHours"),
            sunlightHours: dblVal("sunlightHours"),

            avgHeartRateBpm: dblVal("avgHeartRateBpm"),
            restingHRBpm: dblVal("restingHRBpm"),
            walkingHeartRateAvgBpm: dblVal("walkingHeartRateAvgBpm"),
            hrvSDNNms: dblVal("hrvSDNNms"),
            respiratoryRateBpm: dblVal("respiratoryRateBpm"),
            oxygenSaturationPct: dblVal("oxygenSaturationPct"),
            vo2Max: dblVal("vo2Max"),

            sleepHours: dblVal("sleepHours"),
            deepSleepHours: dblVal("deepSleepHours"),
            remSleepHours: dblVal("remSleepHours"),
            coreSleepHours: dblVal("coreSleepHours"),
            sleepEfficiencyPct: dblVal("sleepEfficiencyPct"),
            wakeAfterSleepOnsetMin: dblVal("wakeAfterSleepOnsetMin"),

            weightKg: dblVal("weightKg"),
            source: d["source"] as? String
        )
    }
}


