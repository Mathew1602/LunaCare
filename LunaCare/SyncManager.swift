//
//  SyncManager.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation


final class SyncManager {
    static let shared = SyncManager()
    let userRepository      = UserRepository()
    private let moodRepo        = MoodLogsRepository()
    private let symptomRepo     = SymptomLogRepository()
    private let measureRepo     = MeasurementRepository()
    private let moodCalRepo     = MoodCalendarRepository()
    private let symptomCalRepo  = SymptomCalendarRepository()

    private let lastSyncKey = "lastCloudSyncDate"
    private var lastCloudSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: lastSyncKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncKey) }
    }

    private init() {}

    // MARK: - Preference
    func applyCloudSyncPreference(uid: String, isOn: Bool, env: AppEnvironment) {
        env.isCloudSyncOn = isOn
        UserDefaults.standard.set(isOn, forKey: "cloudSyncEnabled")
        guard !uid.isEmpty else { return }
        userRepository.setCloudSync(uid: uid, isOn: isOn)
        if isOn {
            Task {
                await MainActor.run {
                    env.syncHasData = false
                    env.isSyncing = true
                    env.syncProgress = 0.0
                }
                await syncLocalToCloud(uid: uid) { progress in
                    Task { @MainActor in
                        env.syncHasData = true
                        env.syncProgress = progress
                    }
                }
                await MainActor.run {
                    env.isSyncing = false
                    env.syncProgress = 1.0
                }
            }
        }
    }

    func getCloudSyncPreference(uid: String, env: AppEnvironment) async -> Bool {
        if uid.isEmpty {
            return env.isCloudSyncOn
        }
        return await withCheckedContinuation { continuation in
            userRepository.fetchCloudSync(uid: uid) { result in
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Sync

    /// Returns `true` if there was local data to sync, `false` if local and cloud are already in sync.
    @discardableResult
    func syncLocalToCloud(uid: String, onProgress: ((Double) -> Void)? = nil) async -> Bool {
        guard !uid.isEmpty else { return false }
        let cutoff = lastCloudSyncDate
        var encounteredError = false

        let moods = LocalMoodStore.shared.loadOfflineMoods().filter { log in
            guard let date = log.createdAt else { return false }
            // Skip entries that originated from the cloud — they are already in Firestore
            // and re-uploading them would create duplicates.
            if log.source == "cloud" { return false }
            return cutoff == nil || date >= cutoff!
        }
        let symptoms = LocalSymptomStore.shared.loadOfflineSymptomLogs().filter { log in
            // Same guard: skip cloud-sourced entries to prevent re-upload duplicates.
            if log.payload.source == "cloud" { return false }
            return cutoff == nil || log.createdAt >= cutoff!
        }

        let localAll = LocalMeasurementStore.shared.loadAll()

        // Nothing to sync — local and cloud are already in sync
        guard !moods.isEmpty || !symptoms.isEmpty else { return false }

        let measurePhases = localAll.isEmpty ? 0 : 1
        let totalPhases = Double(moods.count + symptoms.count + measurePhases)
        var completed = 0.0

        func reportProgress() {
            guard totalPhases > 0 else { return }
            onProgress?(min(completed / totalPhases, 1.0))
        }

        for log in moods {
            do { try await uploadMoodLog(uid: uid, log: log) }
            catch { encounteredError = true }
            completed += 1
            reportProgress()
        }

        for log in symptoms {
            do { try await uploadSymptomLog(uid: uid, log: log) }
            catch { encounteredError = true }
            completed += 1
            reportProgress()
        }

        let dayFmt: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd"
            return f
        }()

        if !localAll.isEmpty {
            let sorted = localAll.sorted { $0.createdAt < $1.createdAt }
            let rangeStart = Calendar.current.startOfDay(for: sorted.first!.createdAt)
            let rangeEnd   = Calendar.current.startOfDay(for: sorted.last!.createdAt)
            do {
                let cloudDates = Set(
                    try await measureRepo.fetchRange(uid: uid, from: rangeStart, to: rangeEnd)
                        .map { dayFmt.string(from: $0.createdAt) }
                )
                let missing = localAll.filter { !cloudDates.contains(dayFmt.string(from: $0.createdAt)) }
                if !missing.isEmpty {
                    _ = try await measureRepo.upsertMany(uid: uid, measurements: missing)
                }
            } catch {
                encounteredError = true
            }
            completed += 1
            reportProgress()
        }

        if !encounteredError {
            lastCloudSyncDate = Date()
        }
        return true
    }

    // MARK: - Cloud → Local

    /// Pulls cloud data down into local stores. Returns `true` if any data was written.
    @discardableResult
    func syncCloudToLocal(uid: String, onProgress: ((Double) -> Void)? = nil) async -> Bool {
        guard !uid.isEmpty else { return false }

        // Date.distantPast (year 0001) is outside Firestore's Timestamp range — use a safe far-back date instead.
        let from = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(timeIntervalSince1970: 0)
        let to   = Date()
        var encounteredError = false

        // Phase 1: Fetch from cloud (50% of progress)
        onProgress?(0.05)

        async let moodsFetch    = moodCalRepo.fetchRange(uid: uid, from: from, to: to)
        async let symptomsFetch = symptomCalRepo.fetchRange(uid: uid, from: from, to: to)
        async let measuresFetch = measureRepo.fetchLastDays(uid: uid, lastDays: 365)

        var cloudMoods:        [CalendarDayLog]    = []
        var cloudSymptoms:     [SymptomLogSummary] = []
        var cloudMeasurements: [Measurement]       = []

        do { cloudMoods        = try await moodsFetch    } catch { encounteredError = true }
        onProgress?(0.2)
        do { cloudSymptoms     = try await symptomsFetch } catch { encounteredError = true }
        onProgress?(0.35)
        do { cloudMeasurements = try await measuresFetch } catch { encounteredError = true }
        onProgress?(0.5)

        guard !cloudMoods.isEmpty || !cloudSymptoms.isEmpty || !cloudMeasurements.isEmpty else {
            onProgress?(1.0)
            return false
        }

        // Phase 2: Save to local stores (remaining 50%)
        let hasMoods    = !cloudMoods.isEmpty
        let hasSymptoms = !cloudSymptoms.isEmpty
        let hasMeasures = !cloudMeasurements.isEmpty
        let saveSteps   = Double([hasMoods, hasSymptoms, hasMeasures].filter { $0 }.count)
        var savesDone   = 0.0

        func saveProgress() {
            guard saveSteps > 0 else { return }
            onProgress?(0.5 + 0.5 * min(savesDone / saveSteps, 1.0))
        }

        if hasMoods {
            // Bulk-save to calendar store (what MoodCalendarViewModel reads),
            // deduplicating by createdAt to avoid duplicates from differing IDs.
            LocalMoodCalendarStore.shared.saveMany(cloudMoods)
            // Also save to raw mood store (used by watch sync and upload)
            for log in cloudMoods {
                let moodLog = MoodLog(
                    id: log.id,
                    mood: moodScore(from: log.mood),
                    notes: log.note,
                    tags: nil,
                    source: "cloud",
                    createdAt: log.createdAt,
                    updatedAt: nil
                )
                LocalMoodStore.shared.saveOfflineMood(moodLog)
            }
            savesDone += 1
            saveProgress()
        }

        if hasSymptoms {
            for summary in cloudSymptoms {
                let values  = Dictionary(uniqueKeysWithValues: summary.rows.map { ($0.name, $0.value) })
                let payload = SymptomLogPayload(values: values, notes: nil, tags: nil, source: "cloud")
                let log     = LocalSymptomLog(payload: payload, createdAt: summary.createdAt)
                LocalSymptomStore.shared.save(log)
            }
            savesDone += 1
            saveProgress()
        }

        if hasMeasures {
            LocalMeasurementStore.shared.saveMany(cloudMeasurements)
            savesDone += 1
            saveProgress()
        }

        return !encounteredError
    }

    private func moodScore(from mood: Mood) -> Int {
        switch mood {
        case .ecstatic: return 4
        case .happy:    return 2
        case .okay:     return 0
        case .sad:      return -1
        case .angry:    return -2
        }
    }

    // MARK: - Private Bridges

    private func uploadMoodLog(uid: String, log: MoodLog) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            moodRepo.createMoodLog(
                uid: uid,
                mood: log.mood,
                notes: log.notes,
                tags: log.tags,
                source: log.source ?? "local",
                createdAt: log.createdAt ?? Date()
            ) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func uploadSymptomLog(uid: String, log: LocalSymptomLog) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            symptomRepo.create(
                uid: uid,
                payload: log.payload,
                createdAt: log.createdAt
            ) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
}
