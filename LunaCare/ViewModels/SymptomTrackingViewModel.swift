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

    // Added for Save button loading state
    @Published var loading = false

    private var syncManager: SyncManager = .shared

    private let repo: SymptomLogRepository


    init(
        repo: SymptomLogRepository =
            SymptomLogRepository()
    ) {

        self.repo = repo

        syncManager = .shared

        self.symptoms = [
            .init(name: "Fatigue"),
            .init(name: "Bleeding"),
            .init(name: "Hair Loss"),
            .init(name: "Appetite"),
            .init(name: "Sleep Trouble"),
        ]
    }


    func save(uid: String) async {

        // Prevent double tap
        guard !loading else {
            return
        }

        loading = true
        backendStatus = nil


        // ==================================================
        // Local save
        // ==================================================

        if !syncManager.isCloudSyncOn ||
            uid.isEmpty {

            let values =
                Dictionary(
                    uniqueKeysWithValues:
                        symptoms.map {
                            (
                                $0.name,
                                Int($0.value)
                            )
                        }
                )


            let payload =
                SymptomLogPayload(
                    values: values,
                    notes: nil,
                    tags: ["manual"],
                    source: "manual"
                )


            LocalSymptomStore.shared
                .saveOfflineSymptomLog(
                    payload
                )


            print(
                "Symptoms saved locally: \(values)"
            )


            backendStatus =
                "Symptoms saved locally."

            loading = false

            showSavedAlert = true

            return
        }


        // ==================================================
        // Firebase save
        // ==================================================

        repo.create(
            uid: uid,
            entries: symptoms,
            notes: nil,
            tags: ["manual"],
            source: "manual"
        ) { [weak self] err in

            guard let self else {
                return
            }

            Task { @MainActor in

                if let err {

                    self.backendStatus =
                        "Symptom save error: \(err.localizedDescription)"

                } else {

                    self.backendStatus =
                        "Symptoms saved."
                }

                self.loading = false
                self.showSavedAlert = true
            }
        }
    }
}
