//
//  CareTeamViewModel.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-10-08.
//

import Foundation

@MainActor
final class CareTeamViewModel: ObservableObject {

    @Published var doctors: [Doctor] = []
    @Published var pendingDoctors: [Doctor] = []
    @Published var comments: [DoctorComment] = []
    @Published var selectedMetric: String? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var actionError: String? = nil
    @Published var inProgressDoctorIds: Set<String> = []

    private let repo = DoctorRepository()

    var commentMetrics: [String] {
        var seen = Set<String>()
        return comments.map(\.metric).filter { seen.insert($0).inserted }
    }

    var filteredComments: [DoctorComment] {
        guard let selectedMetric else { return comments }
        return comments.filter { $0.metric == selectedMetric }
    }

    func load(uid: String) async {
        guard !uid.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
            async let doctors = repo.fetchDoctors(uid: uid)
            async let pending = repo.fetchPendingDoctors(uid: uid)
            async let comments = repo.fetchComments(uid: uid)
            self.doctors = try await doctors
            self.pendingDoctors = try await pending
            self.comments = try await comments
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func approve(_ doctor: Doctor, uid: String) async {
        await perform(on: doctor) {
            try await self.repo.approve(uid: uid, doctorId: doctor.id)
            self.pendingDoctors.removeAll { $0.id == doctor.id }
            if doctor.isAuthorized {
                self.doctors = (self.doctors + [doctor]).sorted { $0.lastName < $1.lastName }
            }
        }
    }

    func decline(_ doctor: Doctor, uid: String) async {
        await perform(on: doctor) {
            try await self.repo.decline(uid: uid, doctorId: doctor.id)
            self.pendingDoctors.removeAll { $0.id == doctor.id }
        }
    }

    private func perform(on doctor: Doctor, _ action: () async throws -> Void) async {
        inProgressDoctorIds.insert(doctor.id)
        defer { inProgressDoctorIds.remove(doctor.id) }
        do {
            try await action()
        } catch {
            actionError = error.localizedDescription
        }
    }
}
