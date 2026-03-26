//
//  MoodTrackingViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-11.
//

import Foundation
import SwiftUI

@MainActor
final class MoodTrackingViewModel: ObservableObject {

    @Published var selectedMood: Mood? = nil
    @Published var note: String = ""
    @Published var createdAt: Date = Date()
    @Published var showSavedAlert = false
    @Published var backendStatus = ""
    @Published var loading = false
    private var syncManager = SyncManager.shared

    private let repo: MoodLogsRepositoryType

    init(repo: MoodLogsRepositoryType = MoodLogsRepository()) {
        syncManager = .shared
        self.repo = repo
    }

    func save(uid: String) async {
        await print(syncManager.getCloudSyncPreference(uid: uid, env: .shared))

        guard !uid.isEmpty else {
            backendStatus = "Not signed in; saved locally only."
            resetUI()
            return
        }
        guard let moodEnum = selectedMood else {
            backendStatus = "Please select a mood."
            return
        }

        if await (!syncManager.getCloudSyncPreference(uid: uid, env: AppEnvironment.shared)) {
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            let moodScore = mapMoodToScore(moodEnum)

            let localLog = MoodLog(
                mood: moodScore,
                notes: trimmed.isEmpty ? nil : trimmed,
                tags: ["manual"],
                source: "manual",
                createdAt: createdAt
            )
            LocalMoodStore.shared.saveOfflineMood(localLog)
            
            let calendarLog = CalendarDayLog(
                id: localLog.id ?? UUID().uuidString,
                mood: moodEnum,
                note: trimmed.isEmpty ? nil : trimmed,
                createdAt: createdAt
            )
            LocalMoodCalendarStore.shared.save(calendarLog)
            backendStatus = "Mood saved locally."
            resetUI()

        } else {
            loading = true
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            let moodScore = mapMoodToScore(moodEnum)

            repo.createMoodLog(
                uid: uid,
                mood: moodScore,
                notes: trimmed.isEmpty ? nil : trimmed,
                tags: ["manual"],
                source: "manual",
                createdAt: createdAt
            ) { [weak self] err in
                Task { @MainActor in
                    if let err = err {
                        self?.backendStatus = "Mood save error: \(err.localizedDescription)"
                    } else {
                        self?.backendStatus = "Mood saved to Firestore"
                        self?.resetUI()
                    }
                    self?.loading = false
                }
            }
        }
    }

    private func resetUI() {
        selectedMood = nil
        note = ""
        createdAt = Date()
        showSavedAlert = true
    }

    private func mapMoodToScore(_ m: Mood) -> Int {
        switch m {
        case .ecstatic: return 4
        case .happy: return 2
        case .okay: return 0
        case .sad: return -1
        case .angry: return -2
        }
    }
}
