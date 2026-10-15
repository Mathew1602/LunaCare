//
//  InsightService.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation

struct InsightDataSnapshot {
    let insights: [WeeklyInsight]
    let measurements: [Measurement]
    let loadErrorMessage: String?
}

@MainActor
final class InsightService {

    static let shared = InsightService()
    private init() {}

    private let repo = MeasurementRepository()
    private let moodRepo = MoodCalendarRepository()
    private let symptomRepo = SymptomCalendarRepository()

    func loadInsights(uid: String) async -> [WeeklyInsight] {
        await loadSnapshot(uid: uid).insights
    }

    func loadSnapshot(uid: String) async -> InsightDataSnapshot {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let from = calendar.date(byAdding: .day, value: -29, to: today) else {
            return InsightDataSnapshot(insights: [], measurements: [], loadErrorMessage: nil)
        }

        if uid.isEmpty || !SyncManager.shared.isCloudSyncOn {
            let measurements = LocalMeasurementStore.shared.fetchRange(from: from, to: now)
            let moods = LocalMoodStore.shared.offlineMoodHistory(from: from, to: now)
            let symptoms = LocalSymptomStore.shared.offlineSymptomHistory(from: from, to: now)
            let records = combining(measurements: measurements, moods: moods, symptoms: symptoms)
            guard !records.isEmpty else {
                return InsightDataSnapshot(insights: [], measurements: records, loadErrorMessage: nil)
            }

            let weekly = WeeklyInsightService.shared.generateWeeklyInsights(
                measurements: records,
                now: now,
                calendar: calendar
            )
            LocalStorageInsights.shared.save(weekly)
            return InsightDataSnapshot(insights: weekly, measurements: records, loadErrorMessage: nil)
        }

        do {
            async let measurementsFetch = repo.fetchRange(uid: uid, from: from, to: now)
            async let moodsFetch = moodRepo.fetchRange(uid: uid, from: from, to: now)
            async let symptomsFetch = symptomRepo.fetchRange(uid: uid, from: from, to: now)
            let (measurements, moods, symptoms) = try await (
                measurementsFetch,
                moodsFetch,
                symptomsFetch
            )
            let records = combining(measurements: measurements, moods: moods, symptoms: symptoms)
            guard !records.isEmpty else {
                return InsightDataSnapshot(insights: [], measurements: records, loadErrorMessage: nil)
            }

            let weekly = WeeklyInsightService.shared.generateWeeklyInsights(
                measurements: records,
                now: now,
                calendar: calendar
            )
            LocalStorageInsights.shared.save(weekly)
            return InsightDataSnapshot(insights: weekly, measurements: records, loadErrorMessage: nil)

        } catch {
            print("Insight load failed: \(error)")
            return InsightDataSnapshot(
                insights: LocalStorageInsights.shared.load(),
                measurements: [],
                loadErrorMessage: error.localizedDescription
            )
        }
    }

    private func combining(
        measurements: [Measurement],
        moods: [CalendarDayLog],
        symptoms: [SymptomLogSummary]
    ) -> [Measurement] {
        var records = measurements
        records.append(contentsOf: moods.map {
            Measurement(
                createdAt: $0.createdAt,
                mood1to5: moodScore($0.mood),
                source: "manual"
            )
        })

        records.append(contentsOf: symptoms.compactMap { log in
            func value(for names: [String]) -> Double? {
                let candidates = Set(names.map { $0.lowercased() })
                return log.rows.first {
                    candidates.contains($0.name.lowercased())
                }.map { Double($0.value) }
            }

            let measurement = Measurement(
                createdAt: log.createdAt,
                bleeding1to10: value(for: ["bleeding"]),
                hairLoss1to10: value(for: ["hair loss"]),
                appetiteIssue1to10: value(for: ["appetite"]),
                sleepTrouble1to10: value(for: ["sleep trouble"]),
                fatigue1to10: value(for: ["fatigue"]),
                source: "manual"
            )

            guard measurement.bleeding1to10 != nil ||
                  measurement.hairLoss1to10 != nil ||
                  measurement.appetiteIssue1to10 != nil ||
                  measurement.sleepTrouble1to10 != nil ||
                  measurement.fatigue1to10 != nil
            else {
                return nil
            }
            return measurement
        })

        return records.sorted { $0.createdAt < $1.createdAt }
    }

    private func moodScore(_ mood: Mood) -> Double {
        switch mood {
        case .ecstatic: return 5
        case .happy: return 4
        case .okay: return 3
        case .sad: return 2
        case .angry: return 1
        }
    }
}
