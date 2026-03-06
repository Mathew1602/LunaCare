//
//  SymptomTrackingViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-14.
//

import Foundation
import SwiftUI

final class SymptomTrackingViewModel: ObservableObject {

    @Published var symptoms: [SymptomEntry]
    @Published var showSavedAlert = false
    @Published var backendStatus: String? = nil

    private let repo: SymptomLogRepository

    init(repo: SymptomLogRepository = SymptomLogRepository()) {
        self.repo = repo
        self.symptoms = [
            .init(name: "Fatigue",       value: 0),
            .init(name: "Bleeding",      value: 0),
            .init(name: "Hair Loss",     value: 0),
            .init(name: "Appetite",      value: 0),
            .init(name: "Sleep Trouble", value: 0)
        ]
    }

    func save(uid: String) {
        guard !uid.isEmpty else {
            backendStatus = "Not signed in; saved locally only."
            showSavedAlert = true
            return
        }

        repo.create(
            uid: uid,
            entries: symptoms,
            notes: nil,
            tags: ["manual"],
            source: "manual"
        ) { [weak self] err in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let err = err {
                    self.backendStatus = "Symptom save error: \(err.localizedDescription)"
                } else {
                    self.backendStatus = "Symptoms saved."
                }
                self.showSavedAlert = true
            }
        }
    }
}
