//
//  DataExportViewModel.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-09-27.
//

import Foundation
import Combine

@MainActor
final class DataExportViewModel: ObservableObject {
    enum ExportFormat: String, CaseIterable, Identifiable {
        case csv = "CSV"
        case pdf = "PDF"
        var id: String { rawValue }
    }

    enum RangeOption: String, CaseIterable, Identifiable {
        case last30   = "Last 30 Days"
        case last90   = "Last 90 Days"
        case lastYear = "Last Year"
        case custom   = "Custom Range"
        case all      = "All History"
        var id: String { rawValue }
    }

    @Published var format: ExportFormat = .csv
    @Published var rangeOption: RangeOption = .last30
    @Published var customFrom: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var customTo: Date = Date()
    @Published var includeHealth = true
    @Published var includeMood = true
    @Published var includeSymptoms = true

    @Published var isExporting = false
    @Published var progress: Double = 0
    @Published var statusText = ""
    @Published var errorText: String?
    @Published var exportedURLs: [URL] = []
    @Published var showShareSheet = false

    private let healthRepo    = AppleWatchDataRepository()
    private let moodCalRepo   = MoodCalendarRepository()
    private let symptomRepo   = SymptomCalendarRepository()
    private let cal = Calendar.current

    var canExport: Bool {
        (includeHealth || includeMood || includeSymptoms) && !isExporting
    }

    func usesCloud(uid: String) -> Bool {
        SyncManager.shared.isCloudSyncOn && !uid.isEmpty
    }

    func export(uid: String, userName: String) async {
        isExporting = true
        progress = 0
        errorText = nil
        exportedURLs = []
        defer { isExporting = false }

        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let allHistoryFloor = cal.date(byAdding: .year, value: -10, to: now) ?? Date(timeIntervalSince1970: 0)

        var from: Date
        var to: Date = now
        switch rangeOption {
        case .last30:   from = cal.date(byAdding: .day, value: -29, to: todayStart)!
        case .last90:   from = cal.date(byAdding: .day, value: -89, to: todayStart)!
        case .lastYear: from = cal.date(byAdding: .year, value: -1, to: todayStart)!
        case .custom:
            from = cal.startOfDay(for: min(customFrom, customTo))
            let endDay = cal.startOfDay(for: max(customFrom, customTo))
            to = min(cal.date(byAdding: .day, value: 1, to: endDay)!.addingTimeInterval(-1), now)
        case .all:      from = allHistoryFloor
        }

        let useCloud = usesCloud(uid: uid)

        var health: [Measurement]? = nil
        if includeHealth {
            statusText = "Reading Apple Health…"
            do {
                try await healthRepo.requestAuthorization()
                var healthFrom = from
                if rangeOption == .all {
                    healthFrom = await healthRepo.earliestSampleDate() ?? todayStart
                }
                let days = await healthRepo.fetchDailyMeasurements(from: healthFrom, to: to) { p in
                    Task { @MainActor in self.progress = p * 0.7 }
                }
                health = days.filter { $0.hasHealthData }
            } catch {
                print("DataExportViewModel health error: \(error.localizedDescription)")
                health = []
            }
        }
        progress = 0.7

        var moods: [CalendarDayLog]? = nil
        if includeMood {
            statusText = "Reading mood logs…"
            if useCloud {
                do {
                    moods = try await moodCalRepo.fetchRange(uid: uid, from: from, to: to)
                } catch {
                    errorText = "Couldn't load mood logs: \(error.localizedDescription)"
                    return
                }
            } else {
                moods = localMoods(from: from, to: to)
            }
        }
        progress = 0.8

        var symptoms: [SymptomLogSummary]? = nil
        if includeSymptoms {
            statusText = "Reading symptom logs…"
            if useCloud {
                do {
                    symptoms = try await symptomRepo.fetchRange(uid: uid, from: from, to: to)
                } catch {
                    errorText = "Couldn't load symptom logs: \(error.localizedDescription)"
                    return
                }
            } else {
                symptoms = LocalSymptomCalendarStore.shared.fetchRange(from: from, to: to)
            }
        }
        progress = 0.9

        statusText = "Creating \(format.rawValue)…"
        var reportFrom = from
        if rangeOption == .all {
            var dates: [Date] = []
            dates += health?.map { $0.createdAt } ?? []
            dates += moods?.map { $0.createdAt } ?? []
            dates += symptoms?.map { $0.createdAt } ?? []
            reportFrom = dates.min() ?? from
        }
        let exporter = DataExporter(
            health: health,
            moods: moods,
            symptoms: symptoms,
            rangeFrom: reportFrom,
            rangeTo: to,
            userName: userName
        )

        do {
            let dir = try DataExporter.makeExportDirectory()
            switch format {
            case .csv: exportedURLs = try exporter.writeCSVFiles(to: dir)
            case .pdf: exportedURLs = [try exporter.writePDF(to: dir)]
            }
            progress = 1
            statusText = "Export ready"
            showShareSheet = true
        } catch {
            errorText = "Couldn't create export: \(error.localizedDescription)"
            statusText = ""
        }
    }

    private func localMoods(from: Date, to: Date) -> [CalendarDayLog] {
        var merged = LocalMoodCalendarStore.shared.fetchRange(from: from, to: to)
        for log in LocalMoodStore.shared.offlineMoodHistory(from: from, to: to) {
            let isDuplicate = merged.contains {
                $0.id == log.id || abs($0.createdAt.timeIntervalSince(log.createdAt)) < 1
            }
            if !isDuplicate { merged.append(log) }
        }
        return merged.sorted { $0.createdAt < $1.createdAt }
    }
}

private extension Measurement {
    var hasHealthData: Bool {
        let values: [Any?] = [
            steps, distanceWalkedKm, flightsClimbed, activeEnergyKcal, basalEnergyKcal,
            exerciseMinutes, standHours, avgHeartRateBpm, restingHRBpm, walkingHeartRateAvgBpm,
            hrvSDNNms, respiratoryRateBpm, oxygenSaturationPct, vo2Max, sleepHours,
            deepSleepHours, remSleepHours, coreSleepHours, sleepEfficiencyPct,
            wakeAfterSleepOnsetMin, weightKg
        ]
        return values.contains { $0 != nil }
    }
}
