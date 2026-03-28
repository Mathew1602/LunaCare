//
//  MeasurementsViewModel.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-24.
//
import Foundation

@MainActor
final class MeasurementsViewModel: ObservableObject {
    
    @Published var lastDays: [Measurement] = []
    @Published var latest: Measurement? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var uploadMessage: String? = nil   // optional for UI feedback
    
    private let repo = MeasurementRepository()
    private let auth: AuthViewModel
    
    init(auth: AuthViewModel) {
        self.auth = auth
    }
    
    func upsert(_ m: Measurement) {
        // Guest / local-only mode
        guard !auth.uid.isEmpty else {
            LocalMeasurementStore.shared.save(m)
            lastDays = LocalMeasurementStore.shared.fetchLastDays()
            latest   = LocalMeasurementStore.shared.fetchLatest()
            return
        }

        repo.upsert(uid: auth.uid, measurement: m) { [weak self] err in
            if let err = err {
                DispatchQueue.main.async {
                    self?.errorMessage = err.localizedDescription
                }
            }
        }
    }
    
    func loadLastDays(_ days: Int = 30) async {
        // Guest / local-only mode
        guard !auth.uid.isEmpty else {
            let records = LocalMeasurementStore.shared.fetchLastDays(days)
            lastDays = records
            latest   = records.last
            return
        }

        isLoading = true
        defer { isLoading = false }
        
        do {
            let records = try await repo.fetchLastDays(uid: auth.uid, lastDays: days)
            lastDays = records
            latest = records.last
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    
    /// Uploads FakeStruct.highRisk30Days() into Firestore under users/{uid}/measurements/{yyyy-MM-dd}
    @Published var isUploading = false

    func uploadTestData() async {
        let fake30 = FakeStruct.extremeHighRisk30Days()

        // Guest / local-only mode
        guard !auth.uid.isEmpty else {
            LocalMeasurementStore.shared.saveMany(fake30)
            uploadMessage = "Saved \(fake30.count) fake measurements locally"
            return
        }

        isUploading = true
        errorMessage = nil
        uploadMessage = nil
        defer { isUploading = false }

        do {
            let written = try await repo.upsertMany(uid: auth.uid, measurements: fake30)
            uploadMessage = "Uploaded \(written) fake day-measurements"
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
    }
    
    /// Wraps completion-based upsert into async/await
    private func upsertAsync(uid: String, measurement: Measurement) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            repo.upsert(uid: uid, measurement: measurement) { err in
                if let err = err {
                    cont.resume(throwing: err)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }
}

