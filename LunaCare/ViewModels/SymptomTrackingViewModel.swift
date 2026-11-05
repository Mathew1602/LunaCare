//
//  SymptomTrackingViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-14.
//

import Foundation
import SwiftUI

@MainActor
final class SymptomTrackingViewModel: ObservableObject {

    @Published var symptoms: [SymptomEntry]
    @Published var showSavedAlert = false
    @Published var errorMessage: String?
    @Published var isSaving = false
    private let syncManager: SyncManager = .shared

    private let repo: SymptomLogRepository

    private static let symptomNames = ["Fatigue", "Bleeding", "Hair Loss", "Appetite", "Sleep Trouble"]

    init(repo: SymptomLogRepository = SymptomLogRepository()) {
        self.repo = repo
        self.symptoms = Self.symptomNames.map { SymptomEntry(name: $0) }
    }

    var canSave: Bool {
        !isSaving && symptoms.contains { $0.level != nil }
    }

    func save(uid: String) async {
        guard canSave else { return }
        errorMessage = nil

        let values = Dictionary(
            symptoms.map { ($0.name, Int($0.value)) },
            uniquingKeysWith: { _, new in new }
        )
        let payload = SymptomLogPayload(values: values, notes: nil, tags: ["manual"], source: "manual")
        let log = LocalSymptomLog(payload: payload, createdAt: Date())

        guard syncManager.isCloudSyncOn, !uid.isEmpty else {
            LocalSymptomStore.shared.save(log)
            didSave()
            return
        }

        isSaving = true
        defer { isSaving = false }
        do {
            try await repo.upsert(uid: uid, log: log)
            didSave()
        } catch {
            errorMessage = "Couldn’t save your symptoms: \(error.localizedDescription)"
        }
    }

    private func didSave() {
        symptoms = Self.symptomNames.map { SymptomEntry(name: $0) }
        showSavedAlert = true
    }
}
