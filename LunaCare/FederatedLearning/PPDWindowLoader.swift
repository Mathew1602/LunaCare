//
//  PPDWindowLoader.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-10-11.
//

import Foundation
import FirebaseFirestore

/// The 30-day ML window: daily measurements merged with mood and symptom logs (latest log per day wins).
/// Used for both on-device scoring and FL contributions so they see the same features.
struct PPDWindowLoader {

    /// Mood.score (4, 2, 0, -1, -2) -> training scale mood_1to5 (higher = better).
    static let moodScale: [Int: Double] = [4: 5, 2: 4, 0: 3, -1: 2, -2: 1]

    /// SymptomLevel values (2/6/9) are already on the 1-10 scale; unselected (0) means "none" = 1.
    static let symptomFields: [String: WritableKeyPath<Measurement, Double?>] = [
        "Fatigue": \.fatigue1to10,
        "Bleeding": \.bleeding1to10,
        "Hair Loss": \.hairLoss1to10,
        "Appetite": \.appetiteIssue1to10,
        "Sleep Trouble": \.sleepTrouble1to10
    ]

    private let measurementRepo = MeasurementRepository()

    func load(uid: String, fromCloud: Bool, windowEnd: Date = Date()) async throws -> [Measurement] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(PPDFeaturePipeline.windowDays - 1),
                             to: cal.startOfDay(for: windowEnd)) ?? windowEnd

        guard fromCloud else {
            let moods = LocalMoodStore.shared.loadOfflineMoods().compactMap { log in
                log.createdAt.map { (date: $0, score: log.mood) }
            }
            let symptoms = LocalSymptomStore.shared.loadOfflineSymptomLogs().map {
                (date: $0.createdAt, values: $0.payload.values)
            }
            return Self.merge(LocalMeasurementStore.shared.fetchRange(from: start, to: windowEnd),
                              moods: moods.filter { $0.date >= start && $0.date <= windowEnd },
                              symptoms: symptoms.filter { $0.date >= start && $0.date <= windowEnd })
        }

        async let measurements = measurementRepo.fetchRange(uid: uid, from: start, to: windowEnd)
        async let moodDocs = logs(FSPath.moodLogs(uid), from: start, to: windowEnd)
        async let symptomDocs = logs(FSPath.symptomLogs(uid), from: start, to: windowEnd)

        let moods = try await moodDocs.compactMap { date, data in
            (data["mood"] as? NSNumber).map { (date: date, score: $0.intValue) }
        }
        let symptoms = try await symptomDocs.compactMap { date, data in
            (data["values"] as? [String: Any]).map { values in
                (date: date, values: values.compactMapValues { ($0 as? NSNumber)?.intValue })
            }
        }
        return Self.merge(try await measurements, moods: moods, symptoms: symptoms)
    }

    static func merge(_ measurements: [Measurement],
                      moods: [(date: Date, score: Int)],
                      symptoms: [(date: Date, values: [String: Int])]) -> [Measurement] {
        var byDay = Dictionary(measurements.map { ($0.dayKey, $0) }) { a, b in a.createdAt >= b.createdAt ? a : b }

        for log in moods.sorted(by: { $0.date < $1.date }) {
            guard let value = moodScale[log.score] else { continue }
            let key = Measurement(createdAt: log.date).dayKey
            var m = byDay[key] ?? Measurement(createdAt: log.date, source: "logs")
            m.mood1to5 = value
            byDay[key] = m
        }

        for log in symptoms.sorted(by: { $0.date < $1.date }) {
            let key = Measurement(createdAt: log.date).dayKey
            var m = byDay[key] ?? Measurement(createdAt: log.date, source: "logs")
            for (name, field) in symptomFields {
                if let raw = log.values[name] { m[keyPath: field] = Double(min(max(raw, 1), 10)) }
            }
            byDay[key] = m
        }

        return byDay.values.sorted { $0.createdAt < $1.createdAt }
    }

    private func logs(_ path: String, from: Date, to: Date) async throws -> [(Date, [String: Any])] {
        try await Firestore.firestore().collection(path)
            .whereField("createdAt", isGreaterThanOrEqualTo: from)
            .whereField("createdAt", isLessThanOrEqualTo: to)
            .getDocuments().documents
            .compactMap { doc in
                let data = doc.data()
                return (data["createdAt"] as? Timestamp).map { ($0.dateValue(), data) }
            }
    }
}
