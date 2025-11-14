//
//  WatchSyncService.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-14

//  WatchSyncService.swift

import Combine
import Foundation

final class WatchSyncService {
    static let shared = WatchSyncService()

    private var cancellable: AnyCancellable?
    private let moodRepo: MoodLogsRepositoryType
    private var uidProvider: () -> String = { "" }   // default empty

    private init(
        wc: WatchConnectivityManager = .shared,
        moodRepo: MoodLogsRepositoryType = MoodLogsRepository()
    ) {
        self.moodRepo = moodRepo

        // Listen for incoming messages
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

        case .measurement:
            // TODO: handle measurements
            break

        case .insight:
            // TODO: handle insights
            break

        case .profile:
            // TODO: handle profile
            break
        }
    }
}
