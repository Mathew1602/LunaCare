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
    @Published var backendStatus: String? = nil
    private var syncManager: SyncManager = .shared

    private let repo: SymptomLogRepository

    init(repo: SymptomLogRepository = SymptomLogRepository()) {
        self.repo = repo
        syncManager = .shared
        self.symptoms = [
            .init(name: "Fatigue", value: 0),
            .init(name: "Bleeding", value: 0),
            .init(name: "Hair Loss", value: 0),
            .init(name: "Appetite", value: 0),
            .init(name: "Sleep Trouble", value: 0),
        ]
    }

    func save(uid: String) async {
        if await
            (!syncManager.getCloudSyncPreference(
                uid: uid,
                env: AppEnvironment.shared
            ) || !uid.isEmpty)
        {
            let values = Dictionary(
                uniqueKeysWithValues: symptoms.map { ($0.name, Int($0.value)) }
            )
            
            let payload = SymptomLogPayload(
                values: values ,
                notes: nil,
                tags: ["manual"],
                source: "manual"
            )
            LocalSymptomStore.shared.saveOfflineSymptomLog(payload)
            print("Symptoms saved locally: \(values)")
            backendStatus = "Symptoms saved locally."
            showSavedAlert = true
        } else {

            repo.create(
                uid: uid,
                entries: symptoms,
                notes: nil,
                tags: ["manual"],
                source: "manual"
            ) { [weak self] err in
                guard let self else { return }
                if let err = err {
                    self.backendStatus =
                        "Symptom save error: \(err.localizedDescription)"
                } else {
                    self.backendStatus = "Symptoms saved."
                }
                self.showSavedAlert = true
            }
        }
    }
}
