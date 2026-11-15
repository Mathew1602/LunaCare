//
//  SyncManager.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation
import FirebaseAuth

enum SyncOutcome {
    case nothingToSync
    case synced
    case failed
}

final class SyncManager {
    static let shared = SyncManager()
    let userRepository      = UserRepository()
    private let moodRepo        = MoodLogsRepository()
    private let symptomRepo     = SymptomLogRepository()
    private let measureRepo     = MeasurementRepository()
    private let moodCalRepo     = MoodCalendarRepository()
    private let symptomCalRepo  = SymptomCalendarRepository()

    private let uploadedKey = "uploadedLogVersions"
    private let legacyLastSyncKey = "lastCloudSyncDate"
    private var syncTask: Task<Void, Never>?

    private init() {}

    // MARK: - Preference

    func applyCloudSyncPreference(uid: String, isOn: Bool, env: AppEnvironment) {
        env.isCloudSyncOn = isOn
        UserDefaults.standard.set(isOn, forKey: "cloudSyncEnabled")
        guard !uid.isEmpty else { return }
        userRepository.setCloudSync(uid: uid, isOn: isOn)
        if isOn {
            startUpload(uid: uid, env: env)
        }
    }

    var isCloudSyncOn: Bool {
        AppEnvironment.shared.isCloudSyncOn
    }

    func startUpload(uid: String, env: AppEnvironment) {
        syncTask?.cancel()
        beginProgress(env: env)
        syncTask = Task {
            let outcome = await syncLocalToCloud(uid: uid) { progress in
                env.syncHasData = true
                env.syncProgress = progress
            }
            guard !Task.isCancelled else { return }
            finishProgress(env: env, failed: outcome == .failed,
                           message: "Some data couldn’t be uploaded. It will retry next time you turn on sync.")
        }
    }

    func startDownload(uid: String, env: AppEnvironment, onFinish: @escaping () -> Void) {
        syncTask?.cancel()
        beginProgress(env: env)
        syncTask = Task {
            let ok = await syncCloudToLocal(uid: uid) { progress in
                env.syncHasData = true
                env.syncProgress = progress
            }
            guard !Task.isCancelled else { return }
            finishProgress(env: env, failed: !ok,
                           message: "Some cloud data couldn’t be downloaded. Check your connection and try again.")
            onFinish()
        }
    }

    func cancelSync(env: AppEnvironment) {
        syncTask?.cancel()
        syncTask = nil
        env.isSyncing = false
        env.syncProgress = 0
    }

    private func beginProgress(env: AppEnvironment) {
        env.syncHasData = false
        env.isSyncing = true
        env.syncProgress = 0
        env.lastSyncError = nil
    }

    private func finishProgress(env: AppEnvironment, failed: Bool, message: String) {
        env.isSyncing = false
        env.syncProgress = 1
        env.lastSyncError = failed ? message : nil
    }

    private func isStillActive(uid: String) -> Bool {
        !Task.isCancelled && Auth.auth().currentUser?.uid == uid
    }

    // MARK: - Local → Cloud

    func syncLocalToCloud(uid: String, onProgress: ((Double) -> Void)? = nil) async -> SyncOutcome {
        guard !uid.isEmpty else { return .nothingToSync }
        seedUploadedVersionsIfNeeded()
        var versions = uploadedVersions
        var encounteredError = false

        let moods = LocalMoodStore.shared.loadOfflineMoods().filter { log in
            guard let id = log.id else { return false }
            return versions[id].map { $0 < Self.version(of: log) } ?? true
        }
        let symptoms = LocalSymptomStore.shared.loadOfflineSymptomLogs().filter { log in
            guard let id = log.id else { return false }
            return versions[id].map { $0 < Self.version(of: log) } ?? true
        }
        let localAll = LocalMeasurementStore.shared.loadAll()

        guard !moods.isEmpty || !symptoms.isEmpty || !localAll.isEmpty else { return .nothingToSync }

        let measurePhases = localAll.isEmpty ? 0 : 1
        let totalPhases = Double(moods.count + symptoms.count + measurePhases)
        var completed = 0.0

        func reportProgress() {
            guard totalPhases > 0 else { return }
            onProgress?(min(completed / totalPhases, 1.0))
        }

        for log in moods {
            guard isStillActive(uid: uid), let id = log.id else { return .failed }
            do {
                try await moodRepo.upsertMoodLog(log, uid: uid)
                versions[id] = Self.version(of: log)
                uploadedVersions = versions
            } catch {
                encounteredError = true
            }
            completed += 1
            reportProgress()
        }

        for log in symptoms {
            guard isStillActive(uid: uid), let id = log.id else { return .failed }
            do {
                try await symptomRepo.upsert(uid: uid, log: log)
                versions[id] = Self.version(of: log)
                uploadedVersions = versions
            } catch {
                encounteredError = true
            }
            completed += 1
            reportProgress()
        }

        if !localAll.isEmpty, isStillActive(uid: uid) {
            let sorted = localAll.sorted { $0.createdAt < $1.createdAt }
            let rangeStart = Calendar.current.startOfDay(for: sorted[0].createdAt)
            let rangeEnd   = Calendar.current.startOfDay(for: sorted[sorted.count - 1].createdAt)
            do {
                let cloudDates = Set(
                    try await measureRepo.fetchRange(uid: uid, from: rangeStart, to: rangeEnd)
                        .map(\.dayKey)
                )
                let missing = localAll.filter { !cloudDates.contains($0.dayKey) }
                if !missing.isEmpty, isStillActive(uid: uid) {
                    _ = try await measureRepo.upsertMany(uid: uid, measurements: missing)
                }
                if isStillActive(uid: uid) {
                    await HealthDataPersistence.shared.uploadPending(uid: uid)
                }
            } catch {
                encounteredError = true
            }
            completed += 1
            reportProgress()
        }

        return encounteredError ? .failed : .synced
    }

    // MARK: - Cloud → Local

    /// Pulls cloud data down into local stores. Returns `false` if any part of the download failed.
    @discardableResult
    func syncCloudToLocal(uid: String, onProgress: ((Double) -> Void)? = nil) async -> Bool {
        guard !uid.isEmpty else { return false }

        // Date.distantPast (year 0001) is outside Firestore's Timestamp range — use a safe far-back date instead.
        let from = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(timeIntervalSince1970: 0)
        let to   = Date()
        var encounteredError = false

        onProgress?(0.05)

        async let moodsFetch    = moodCalRepo.fetchRange(uid: uid, from: from, to: to)
        async let symptomsFetch = symptomCalRepo.fetchRange(uid: uid, from: from, to: to)
        async let measuresFetch = measureRepo.fetchRange(uid: uid, from: from, to: to)

        var cloudMoods:        [CalendarDayLog]    = []
        var cloudSymptoms:     [SymptomLogSummary] = []
        var cloudMeasurements: [Measurement]       = []

        do { cloudMoods        = try await moodsFetch    } catch { encounteredError = true }
        onProgress?(0.2)
        do { cloudSymptoms     = try await symptomsFetch } catch { encounteredError = true }
        onProgress?(0.35)
        do { cloudMeasurements = try await measuresFetch } catch { encounteredError = true }
        onProgress?(0.5)

        guard isStillActive(uid: uid) else { return false }
        guard !cloudMoods.isEmpty || !cloudSymptoms.isEmpty || !cloudMeasurements.isEmpty else {
            onProgress?(1.0)
            return !encounteredError
        }

        let hasMoods    = !cloudMoods.isEmpty
        let hasSymptoms = !cloudSymptoms.isEmpty
        let hasMeasures = !cloudMeasurements.isEmpty
        let saveSteps   = Double([hasMoods, hasSymptoms, hasMeasures].filter { $0 }.count)
        var savesDone   = 0.0
        var versions    = uploadedVersions

        func saveProgress() {
            guard saveSteps > 0 else { return }
            onProgress?(0.5 + 0.5 * min(savesDone / saveSteps, 1.0))
        }

        if hasMoods {
            let localMoods = LocalMoodStore.shared.loadOfflineMoods()
            for log in cloudMoods {
                let hasPendingEdit = localMoods.contains { local in
                    guard let id = local.id, id == log.id else { return false }
                    return versions[id].map { $0 < Self.version(of: local) } ?? true
                }
                if hasPendingEdit { continue }
                let moodLog = MoodLog(
                    id: log.id,
                    mood: log.mood.score,
                    notes: log.note,
                    tags: nil,
                    source: "cloud",
                    createdAt: log.createdAt,
                    updatedAt: nil
                )
                LocalMoodStore.shared.saveOfflineMood(moodLog)
                versions[log.id] = Self.version(of: moodLog)
            }
            savesDone += 1
            saveProgress()
        }

        if hasSymptoms {
            for summary in cloudSymptoms {
                let values  = Dictionary(summary.rows.map { ($0.name, $0.value) }, uniquingKeysWith: { _, new in new })
                let payload = SymptomLogPayload(values: values, notes: nil, tags: nil, source: "cloud")
                let log     = LocalSymptomLog(id: summary.id, payload: payload, createdAt: summary.createdAt)
                LocalSymptomStore.shared.save(log)
                if let id = log.id { versions[id] = Self.version(of: log) }
            }
            savesDone += 1
            saveProgress()
        }

        uploadedVersions = versions

        if hasMeasures {
            LocalMeasurementStore.shared.saveMany(cloudMeasurements)
            savesDone += 1
            saveProgress()
        }

        return !encounteredError
    }

    // MARK: - Upload tracking

    private var uploadedVersions: [String: Double] {
        get { StorageScope.object(forKey: uploadedKey) as? [String: Double] ?? [:] }
        set { StorageScope.set(newValue, forKey: uploadedKey) }
    }

    private static func version(of log: MoodLog) -> Double {
        (log.updatedAt ?? log.createdAt ?? .distantPast).timeIntervalSince1970
    }

    private static func version(of log: LocalSymptomLog) -> Double {
        (log.updatedAt ?? log.createdAt).timeIntervalSince1970
    }

    // Before per-log tracking, uploads were filtered by a single "last sync" time.
    // Anything older than that, or downloaded from the cloud, is already in Firestore.
    private func seedUploadedVersionsIfNeeded() {
        guard StorageScope.object(forKey: uploadedKey) == nil else { return }
        let cutoff = UserDefaults.standard.object(forKey: legacyLastSyncKey) as? Date
        var versions: [String: Double] = [:]

        for log in LocalMoodStore.shared.loadOfflineMoods() {
            guard let id = log.id else { continue }
            let alreadyUploaded = log.source == "cloud" || (cutoff.map { (log.createdAt ?? .distantFuture) < $0 } ?? false)
            if alreadyUploaded { versions[id] = Self.version(of: log) }
        }
        for log in LocalSymptomStore.shared.loadOfflineSymptomLogs() {
            guard let id = log.id else { continue }
            let alreadyUploaded = log.payload.source == "cloud" || (cutoff.map { log.createdAt < $0 } ?? false)
            if alreadyUploaded { versions[id] = Self.version(of: log) }
        }

        uploadedVersions = versions
        UserDefaults.standard.removeObject(forKey: legacyLastSyncKey)
    }
}
