import Combine
import Foundation

@MainActor
final class HealthSummaryViewModel: ObservableObject {
    @Published var period: HealthSummaryPeriod = .week
    @Published var includeMood = true
    @Published var includeSymptoms = true
    @Published var includeSleep = true
    @Published var includeName = false
    @Published private(set) var snapshot: HealthSummarySnapshot?
    @Published private(set) var isLoading = false
    @Published var errorText: String?
    @Published private(set) var sourceWarning: String?
    @Published private(set) var exportedURL: URL?
    @Published var showShareSheet = false

    private let healthRepository = AppleWatchDataRepository()
    private let moodRepository = MoodCalendarRepository()
    private let symptomRepository = SymptomCalendarRepository()
    private let calendar = Calendar.current
    private var activeLoadID = UUID()

    var canExport: Bool {
        snapshot != nil &&
        (includeMood || includeSymptoms || includeSleep) &&
        !isLoading
    }

    func load(uid: String, userName: String) async {
        let loadID = UUID()
        activeLoadID = loadID
        isLoading = true
        snapshot = nil
        errorText = nil
        sourceWarning = nil
        defer {
            if activeLoadID == loadID {
                isLoading = false
            }
        }

        let today = calendar.startOfDay(for: Date())
        guard
            let rangeFrom = calendar.date(byAdding: .day, value: -(period.days - 1), to: today),
            let rangeTo = calendar.date(byAdding: .day, value: 1, to: today),
            let previousFrom = calendar.date(byAdding: .day, value: -period.days, to: rangeFrom)
        else {
            errorText = "Couldn't prepare the selected date range."
            return
        }
        let previousTo = rangeFrom

        var moods: [CalendarDayLog] = []
        var previousMoods: [CalendarDayLog] = []
        var symptoms: [SymptomLogSummary] = []
        var previousSymptoms: [SymptomLogSummary] = []
        let useCloud = SyncManager.shared.isCloudSyncOn && !uid.isEmpty

        do {
            if includeMood {
                let logs: [CalendarDayLog]
                if useCloud {
                    logs = try await moodRepository.fetchRange(uid: uid, from: previousFrom, to: rangeTo)
                } else {
                    logs = localMoods(from: previousFrom, to: rangeTo)
                }
                guard activeLoadID == loadID else { return }
                moods = logs.filter { $0.createdAt >= rangeFrom && $0.createdAt < rangeTo }
                previousMoods = logs.filter { $0.createdAt >= previousFrom && $0.createdAt < previousTo }
            }

            if includeSymptoms {
                let logs: [SymptomLogSummary]
                if useCloud {
                    logs = try await symptomRepository.fetchRange(uid: uid, from: previousFrom, to: rangeTo)
                } else {
                    logs = LocalSymptomCalendarStore.shared.fetchRange(from: previousFrom, to: rangeTo)
                }
                guard activeLoadID == loadID else { return }
                symptoms = logs.filter { $0.createdAt >= rangeFrom && $0.createdAt < rangeTo }
                previousSymptoms = logs.filter { $0.createdAt >= previousFrom && $0.createdAt < previousTo }
            }
        } catch {
            guard activeLoadID == loadID else { return }
            errorText = "Couldn't load your mood and symptom logs: \(error.localizedDescription)"
            return
        }

        var health: [Measurement] = []
        if includeSleep {
            do {
                try await healthRepository.requestAuthorization()
                guard activeLoadID == loadID else { return }
                health = await healthRepository.fetchDailyMeasurements(from: rangeFrom, to: today)
                guard activeLoadID == loadID else { return }
                health = health.filter { $0.sleepHours != nil }
            } catch {
                guard activeLoadID == loadID else { return }
                sourceWarning = "Apple Health sleep data couldn't be loaded: \(error.localizedDescription)"
            }
        }

        snapshot = HealthSummarySnapshot.make(
            period: period,
            rangeFrom: rangeFrom,
            rangeTo: today,
            userName: userName,
            moods: moods,
            previousMoods: previousMoods,
            symptoms: symptoms,
            previousSymptoms: previousSymptoms,
            health: health
        )
    }

    func export() {
        guard let snapshot, canExport else { return }
        do {
            let directory = try DataExporter.makeExportDirectory()
            exportedURL = try HealthSummaryPDFExporter.write(
                snapshot: snapshot,
                includeMood: includeMood,
                includeSymptoms: includeSymptoms,
                includeSleep: includeSleep,
                includeName: includeName,
                to: directory
            )
            showShareSheet = true
        } catch {
            errorText = "Couldn't create the appointment summary: \(error.localizedDescription)"
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
