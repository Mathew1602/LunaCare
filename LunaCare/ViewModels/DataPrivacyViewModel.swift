//
//  DataPrivacyViewModel.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-10-08.
//

import Foundation

@MainActor
final class DataPrivacyViewModel: ObservableObject {

    @Published var counts: [String: Int] = [:]
    @Published var doctors: [Doctor] = []
    @Published var pendingCount = 0
    @Published var consent = ConsentSettings()
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var actionError: String? = nil
    @Published var revokingDoctorIds: Set<String> = []
    @Published var isDeleting = false
    @Published var deleteError: String? = nil

    private let privacyRepo = PrivacyRepository()
    private let doctorRepo = DoctorRepository()

    func load(uid: String) async {
        guard !uid.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
            async let counts = privacyRepo.fetchCounts(uid: uid)
            async let doctors = doctorRepo.fetchDoctors(uid: uid)
            async let pending = doctorRepo.fetchPendingDoctors(uid: uid)
            async let consent = privacyRepo.fetchConsent(uid: uid)
            self.counts = try await counts
            self.doctors = try await doctors
            self.pendingCount = try await pending.count
            self.consent = try await consent
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func revoke(_ doctor: Doctor, uid: String) async {
        revokingDoctorIds.insert(doctor.id)
        defer { revokingDoctorIds.remove(doctor.id) }
        do {
            try await doctorRepo.revoke(uid: uid, doctorId: doctor.id)
            doctors.removeAll { $0.id == doctor.id }
        } catch {
            actionError = error.localizedDescription
        }
    }

    func setConsent(_ key: ConsentKey, to value: Bool, uid: String) async {
        let previous = consent
        switch key {
        case .shareWithDoctors: consent.shareWithDoctors = value
        case .riskInsights: consent.riskInsights = value
        }
        do {
            try await privacyRepo.setConsent(uid: uid, key: key, value: value)
            consent.updatedAt = Date()
        } catch {
            consent = previous
            actionError = error.localizedDescription
        }
    }

    func deleteAccount(password: String) async -> Bool {
        isDeleting = true
        deleteError = nil
        defer { isDeleting = false }
        do {
            try await privacyRepo.deleteAccount(password: password)
            return true
        } catch {
            deleteError = error.localizedDescription
            return false
        }
    }
}
