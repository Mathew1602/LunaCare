//
//  SyncManager.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation


final class SyncManager {
    static let shared = SyncManager()
    let userRepository   = UserRepository()
    private let moodRepo     = MoodLogsRepository()
    private let symptomRepo  = SymptomLogRepository()
    private let measureRepo  = MeasurementRepository()

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
                    env.isSyncing = true
                    env.syncProgress = 0.0
                }
                await syncLocalToCloud(uid: uid) { progress in
                    Task { @MainActor in env.syncProgress = progress }
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

    func syncLocalToCloud(uid: String, onProgress: ((Double) -> Void)? = nil) async {
        guard !uid.isEmpty else { return }
        let cutoff = lastCloudSyncDate
        var encounteredError = false

        let moods = LocalMoodStore.shared.loadOfflineMoods().filter { log in
            guard let date = log.createdAt else { return false }
            return cutoff == nil || date >= cutoff!
        }
        let symptoms = LocalSymptomStore.shared.loadOfflineSymptomLogs().filter { log in
            cutoff == nil || log.createdAt >= cutoff!
        }
        let localAll = LocalMeasurementStore.shared.loadAll()

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
