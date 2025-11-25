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
        let uid = auth.uid
        guard !uid.isEmpty else {
            errorMessage = "No user signed in."
            return
        }
        
        repo.upsert(uid: uid, measurement: m) { [weak self] err in
            if let err = err {
                DispatchQueue.main.async {
                    self?.errorMessage = err.localizedDescription
                }
            }
        }
    }
    
    func loadLastDays(_ days: Int = 30) async {
        let uid = auth.uid
        guard !uid.isEmpty else {
            errorMessage = "No user signed in."
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let records = try await repo.fetchLastDays(uid: uid, lastDays: days)
            lastDays = records
            latest = records.last
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    
    /// Uploads FakeStruct.highRisk30Days() into Firestore under users/{uid}/measurements/{yyyy-MM-dd}
    @Published var isUploading = false

    func uploadTestData() async {
        let uid = auth.uid
        guard !uid.isEmpty else {
            errorMessage = "No user signed in."
            return
        }

        isUploading = true
        errorMessage = nil
        uploadMessage = nil
        defer { isUploading = false }

        let fake30 = FakeStruct.highRisk30Days()

        do {
            let written = try await repo.upsertMany(uid: uid, measurements: fake30)
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

