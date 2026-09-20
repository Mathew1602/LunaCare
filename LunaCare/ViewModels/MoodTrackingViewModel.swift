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
        guard let moodEnum = selectedMood else {
            backendStatus = "Please select a mood."
            return
        }

        if !syncManager.isCloudSyncOn {
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            let moodScore = moodEnum.score

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
            let moodScore = moodEnum.score

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
}
