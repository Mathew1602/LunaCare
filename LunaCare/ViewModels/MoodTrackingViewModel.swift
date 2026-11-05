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
    @Published var errorMessage: String?
    @Published var loading = false
    private let syncManager = SyncManager.shared

    private let repo: MoodLogsRepositoryType

    init(repo: MoodLogsRepositoryType = MoodLogsRepository()) {
        self.repo = repo
    }

    var canSave: Bool {
        !loading && selectedMood != nil
    }

    func save(uid: String) async {
        guard let moodEnum = selectedMood, !loading else { return }
        errorMessage = nil

        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = MoodLog(
            id: UUID().uuidString,
            mood: moodEnum.score,
            notes: trimmed.isEmpty ? nil : trimmed,
            tags: ["manual"],
            source: "manual",
            createdAt: min(createdAt, Date()),
            updatedAt: Date()
        )

        guard syncManager.isCloudSyncOn, !uid.isEmpty else {
            LocalMoodStore.shared.saveOfflineMood(log)
            resetUI()
            return
        }

        loading = true
        defer { loading = false }
        do {
            try await repo.upsertMoodLog(log, uid: uid)
            resetUI()
        } catch {
            errorMessage = "Couldn’t save your mood: \(error.localizedDescription)"
        }
    }

    private func resetUI() {
        selectedMood = nil
        note = ""
        createdAt = Date()
        showSavedAlert = true
    }
}
