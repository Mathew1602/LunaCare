//
//  WatchSyncService.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-14.
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

    // Called from the app once AuthViewModel exists
    func configure(uidProvider: @escaping () -> String) {
        self.uidProvider = uidProvider
    }

    private func handle(_ msg: SyncMessage) {
        let uid = uidProvider()

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
                    payload: payload,
                    completion: { error in
                        if let error = error {
                            print("Symptom log save error: \(error.localizedDescription)")
                        } else {
                            print("Symptom log saved to Firestore")
                        }
                    }
                )
            }

        case .measurement:
            // TODO: handle measurements
            break

        case .insight:
            // TODO: handle insights
            break

        case .profile:
            // TODO: handle profile
            break

        // MARK: - Mood history request
        case .getMoodRequest:
            guard let request = msg.getMoodRequest else { return }
            print("GetMoodRequest received: \(request.from) to \(request.to)")

            guard !uid.isEmpty else {
                print("No UID – cannot fetch mood history from Firestore.")
                WatchConnectivityManager.shared.send(
                    [CalendarDayLog](),
                    type: .getMoodResponse
                )
                return
            }

            Task { [weak self] in
                guard let self = self else { return }

                do {
                    let logs = try await self.calendarRepo.fetchRange(
                        uid: uid,
                        from: request.from,
                        to: request.to
                    )

                    let sorted = logs.sorted { $0.createdAt > $1.createdAt }
                    print("Fetched \(sorted.count) mood logs for watch from Firestore")

                    WatchConnectivityManager.shared.send(
                        sorted,
                        type: .getMoodResponse
                    )
                    print("GetMoodResponse sent with \(sorted.count) items")
                } catch {
                    print("Error fetching mood history for watch: \(error.localizedDescription)")
                    WatchConnectivityManager.shared.send(
                        [CalendarDayLog](),
                        type: .getMoodResponse
                    )
                }
            }

        case .getMoodResponse:
            guard let log = msg.getMoodResponse else { return }
            print("GetMoodResponse received: \(log.count) items")
            // Optional: store for later

        // MARK: - Symptom history request (last 5 days)
        case .getSymptomRequest:
            guard let request = msg.getSymptomRequest else { return }
            print("GetSymptomRequest received: \(request.from) to \(request.to)")

            guard !uid.isEmpty else {
                print("No UID – cannot fetch symptom history from Firestore.")
                WatchConnectivityManager.shared.send(
                    [SymptomDaySummary](),
                    type: .getSymptomResponse
                )
                return
            }

            Task { [weak self] in
                guard let self = self else { return }

                do {
                    let cal = Calendar.current
                    var currentDay = cal.startOfDay(for: request.from)
                    let endDay = cal.startOfDay(for: request.to)

                    var daySummaries: [SymptomDaySummary] = []

                    while currentDay <= endDay {
                        let dayValues = try await self.symptomRepo.fetchDayValues(
                            uid: uid,
                            day: currentDay
                        )

                        let rowsForDay = dayValues
                            .map { SymptomRow(name: $0.key, value: $0.value) }
                            .sorted { $0.value > $1.value }

                        if !rowsForDay.isEmpty {
                            let summary = SymptomDaySummary(
                                date: currentDay,
                                rows: rowsForDay
                            )
                            daySummaries.append(summary)
                        }

                        guard let next = cal.date(byAdding: .day, value: 1, to: currentDay) else { break }
                        currentDay = next
                    }

                    let sortedDays = daySummaries.sorted { $0.date > $1.date }

                    print("Fetched \(sortedDays.count) symptom days for watch")

                    WatchConnectivityManager.shared.send(
                        sortedDays,
                        type: .getSymptomResponse
                    )
                    print("GetSymptomResponse sent with \(sortedDays.count) days")

                } catch {
                    print("Error fetching symptom history for watch: \(error.localizedDescription)")
                    WatchConnectivityManager.shared.send(
                        [SymptomDaySummary](),
                        type: .getSymptomResponse
                    )
                }
            }

        case .getSymptomResponse:
            guard let rows = msg.getSymptomResponse else { return }
            print("GetSymptomResponse received: \(rows.count) items")
            // Optional: store or forward to some local store
        }
    }
}
