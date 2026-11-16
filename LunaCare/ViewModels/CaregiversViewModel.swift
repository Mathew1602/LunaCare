//
//  CaregiversViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-15.
//

import Foundation

/// Mother-side management of linked caregivers and what each one can see.
@MainActor
final class CaregiversViewModel: ObservableObject {

    @Published private(set) var caregivers: [Caregiver] = []
    @Published private(set) var isLoading = false
    @Published private(set) var inProgressIds: Set<String> = []
    @Published var errorMessage: String? = nil

    private let repo: CaregiverRepository

    init(repo: CaregiverRepository = CaregiverRepository()) {
        self.repo = repo
    }

    func load(uid: String) async {
        guard !uid.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            caregivers = try await repo.fetchCaregivers(uid: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Applies the change immediately so toggles feel responsive; rolls back if the write fails.
    func update(_ permissions: CaregiverPermissions, for caregiver: Caregiver, uid: String, motherName: String) async {
        let previous = caregiver.permissions
        setPermissions(permissions, for: caregiver.id)

        await perform(on: caregiver) {
            do {
                try await self.repo.updatePermissions(uid: uid, motherName: motherName,
                                                      caregiverId: caregiver.id, permissions: permissions)
            } catch {
                self.setPermissions(previous, for: caregiver.id)
                throw error
            }
        }
    }

    func remove(_ caregiver: Caregiver, uid: String) async {
        await perform(on: caregiver) {
            try await self.repo.remove(uid: uid, caregiverId: caregiver.id)
            self.caregivers.removeAll { $0.id == caregiver.id }
        }
    }

    private func setPermissions(_ permissions: CaregiverPermissions, for id: String) {
        guard let index = caregivers.firstIndex(where: { $0.id == id }) else { return }
        caregivers[index].permissions = permissions
    }

    private func perform(on caregiver: Caregiver, _ action: () async throws -> Void) async {
        inProgressIds.insert(caregiver.id)
        defer { inProgressIds.remove(caregiver.id) }
        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
