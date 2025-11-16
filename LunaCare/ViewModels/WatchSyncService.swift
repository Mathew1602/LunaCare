//
//  WatchSyncService.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-14.
//
//

import Combine
import Foundation

final class WatchSyncService {
    static let shared = WatchSyncService()

    private var cancellable: AnyCancellable?
    private let moodRepo: MoodLogsRepositoryType
    private let calendarRepo: MoodCalendarRepository
    private let symptomRepo: SymptomCalendarRepository
    private var uidProvider: () -> String = { "" }
    private var useCloudProvider: () -> Bool = { true }

    private init(
        wc: WatchConnectivityManager = .shared,
        moodRepo: MoodLogsRepositoryType = MoodLogsRepository(),
        calendarRepo: MoodCalendarRepository = MoodCalendarRepository(),
        symptomRepo: SymptomCalendarRepository = SymptomCalendarRepository()
    ) {
        self.moodRepo = moodRepo
        self.calendarRepo = calendarRepo
        self.symptomRepo = symptomRepo

        cancellable = wc.$lastReceived
            .compactMap { $0 }
            .sink { [weak self] msg in
                self?.handle(msg)
            }
    }

    func configure(
        uidProvider: @escaping () -> String,
        useCloudProvider: @escaping () -> Bool
    ) {
        self.uidProvider = uidProvider
        self.useCloudProvider = useCloudProvider
    }

    private func handle(_ msg: SyncMessage) {
        let uid = uidProvider()
        let useCloud = useCloudProvider()

        switch msg.type {

        case .moodLog:
            guard var m = msg.moodLog else { return }

            if uid.isEmpty {
                print("No UID. Saving mood locally.")
                if m.createdAt == nil { m.createdAt = Date() }
                LocalMoodStore.shared.saveOfflineMood(m)
            } else {
                print("Saving watch mood to Firestore. uid = \(uid)")
                moodRepo.createMoodLog(
                    uid: uid,
                    mood: m.mood,
                    notes: m.notes,
                    tags: m.tags ?? ["watch"],
                    source: m.source ?? "watch",
                    createdAt: m.createdAt ?? Date(),
                    completion: nil
                )
            }

        case .symptomLog:
            guard let payload = msg.symptomLog else { return }

            if uid.isEmpty {
                print("No UID. Saving symptom log locally.")
                LocalSymptomStore.shared.saveOfflineSymptomLog(payload)
            } else {
                print("Saving watch symptom log to Firestore. uid = \(uid)")
                SymptomLogRepository().create(
                    uid: uid,
                    payload: payload
                ) { error in
                    if let error = error {
                        print("Symptom log save error: \(error.localizedDescription)")
                    } else {
                        print("Symptom log saved to Firestore")
                    }
                }
            }

        case .measurement:
            break

        case .insight:
            break

        case .profile:
            break

        // MARK: - Mood history request
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

        // MARK: - Symptom history request (range)
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
        }
    }
}
