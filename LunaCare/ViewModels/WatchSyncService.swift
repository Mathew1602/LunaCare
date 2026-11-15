//
//  WatchSyncService.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-14.
//

import Combine
import Foundation
import FirebaseAuth

final class WatchSyncService {
    static let shared = WatchSyncService()

    private var cancellable: AnyCancellable?
    private let moodRepo: MoodLogsRepositoryType
    private let calendarRepo: MoodCalendarRepository
    private let symptomRepo: SymptomCalendarRepository
    private var syncManager = SyncManager.shared
    private var useCloudProvider: Bool { syncManager.isCloudSyncOn }

    private init(
        wc: WatchConnectivityManager = .shared,
        syncManager: SyncManager = .shared,
        moodRepo: MoodLogsRepositoryType = MoodLogsRepository(),
        calendarRepo: MoodCalendarRepository = MoodCalendarRepository(),
        symptomRepo: SymptomCalendarRepository = SymptomCalendarRepository()
    ) {
        self.syncManager = syncManager
        self.moodRepo = moodRepo
        self.calendarRepo = calendarRepo
        self.symptomRepo = symptomRepo

        cancellable = wc.$lastReceived
            .compactMap { $0 }
            .sink { [weak self] msg in
                self?.handle(msg)
            }
    }
    
    private func handle(_ msg: SyncMessage) {
        let uid = Auth.auth().currentUser?.uid ?? ""
        let useCloud = useCloudProvider

        switch msg.type {

        case .moodLog:
            guard var m = msg.moodLog else { return }
            if m.createdAt == nil { m.createdAt = Date() }
            if m.id == nil { m.id = UUID().uuidString }
            if m.tags == nil { m.tags = ["watch"] }
            if m.source == nil { m.source = "watch" }

            if uid.isEmpty || !useCloud {
                LocalMoodStore.shared.saveOfflineMood(m)
            } else {
                let log = m
                Task {
                    do {
                        try await self.moodRepo.upsertMoodLog(log, uid: uid)
                    } catch {
                        print("Watch mood upload failed, kept locally: \(error.localizedDescription)")
                        LocalMoodStore.shared.saveOfflineMood(log)
                    }
                }
            }

        case .symptomLog:
            guard let payload = msg.symptomLog else { return }
            let log = LocalSymptomLog(payload: payload, createdAt: Date())

            if uid.isEmpty || !useCloud {
                LocalSymptomStore.shared.save(log)
            } else {
                Task {
                    do {
                        try await SymptomLogRepository().upsert(uid: uid, log: log)
                    } catch {
                        print("Watch symptom upload failed, kept locally: \(error.localizedDescription)")
                        LocalSymptomStore.shared.save(log)
                    }
                }
            }

        case .measurement:
            break

        case .insight:
            break

        case .profile:
            guard let profile = msg.profile else { return }
            print("Profile received on \(uid.isEmpty ? "watch (offline)" : "watch") : \(profile.fullName)")


        case .getMoodRequest:
            guard let request = msg.getMoodRequest else { return }
            print("GetMoodRequest received: \(request.from) to \(request.to)")

            if !useCloud || uid.isEmpty {
                print("Using offline mood history.")
                let logs = LocalMoodStore.shared.offlineMoodHistory(from: request.from, to: request.to)
                WatchConnectivityManager.shared.send(logs, type: .getMoodResponse)
                print("Offline GetMoodResponse sent with \(logs.count) items")
                return
            }

            Task { [weak self] in
                guard let self else { return }

                do {
                    let logs = try await self.calendarRepo.fetchRange(
                        uid: uid,
                        from: request.from,
                        to: request.to
                    )

                    let sorted = logs.sorted { $0.createdAt > $1.createdAt }
                    WatchConnectivityManager.shared.send(sorted, type: .getMoodResponse)
                    print("GetMoodResponse sent with \(sorted.count) items")
                } catch {
                    print("Error fetching mood history for watch: \(error.localizedDescription)")
                    WatchConnectivityManager.shared.send([CalendarDayLog](), type: .getMoodResponse)
                }
            }

        case .getMoodResponse:
            guard let log = msg.getMoodResponse else { return }
            print("GetMoodResponse received: \(log.count) items")

        case .getSymptomRequest:
            guard let request = msg.getSymptomRequest else { return }
            print("GetSymptomRequest received: \(request.from) to \(request.to)")

            if !useCloud || uid.isEmpty {
                print("Using offline symptom history.")
                let summaries = LocalSymptomStore.shared.offlineSymptomHistory(from: request.from, to: request.to)
                WatchConnectivityManager.shared.send(summaries, type: .getSymptomResponse)
                print("Offline GetSymptomResponse sent with \(summaries.count) logs")
                return
            }

            Task { [weak self] in
                guard let self else { return }

                do {
                    let logs = try await self.symptomRepo.fetchRange(
                        uid: uid,
                        from: request.from,
                        to: request.to
                    )

                    WatchConnectivityManager.shared.send(logs, type: .getSymptomResponse)
                    print("GetSymptomResponse sent with \(logs.count) logs")
                } catch {
                    print("Error fetching symptom history for watch: \(error.localizedDescription)")
                    WatchConnectivityManager.shared.send([SymptomLogSummary](), type: .getSymptomResponse)
                }
            }

        case .getSymptomResponse:
            guard let rows = msg.getSymptomResponse else { return }
            print("GetSymptomResponse received: \(rows.count) items")

        case .getRiskRequest:
            Task {
                let result = await PPDRiskCheck.run(uid: uid, fromCloud: !uid.isEmpty && useCloud)
                WatchConnectivityManager.shared.send(result.watchSummary, type: .getRiskResponse)
            }

        case .getRiskResponse:
            break
        }
    }
}
