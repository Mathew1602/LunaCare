//
//  CaregiversViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-15.
//

import Foundation

/// Mother-side management of linked caregivers, what each one can see, and pending invites.
@MainActor
final class CaregiversViewModel: ObservableObject {

    @Published private(set) var caregivers: [Caregiver] = []
    @Published private(set) var invites: [CaregiverInvite] = []
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

        async let invites = loadInvites(uid: uid)
        do {
            caregivers = try await repo.fetchCaregivers(uid: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
        self.invites = await invites
    }

    /// Loaded independently so a failure here never hides the linked caregivers.
    private func loadInvites(uid: String) async -> [CaregiverInvite] {
        do {
            return try await repo.fetchInvites(uid: uid)
        } catch {
            print("Failed to load caregiver invites:", error)
            return []
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

    /// Returns the new invite so the sheet can show its code, or nil if creation failed.
    func createInvite(email: String, relationship: String, permissions: CaregiverPermissions, uid: String) async -> CaregiverInvite? {
        guard CaregiverInvite.isValidEmail(email) else {
            errorMessage = "Enter a valid email address."
            return nil
        }
        do {
            let invite = try await repo.createInvite(uid: uid, email: email, relationship: relationship, permissions: permissions)
            invites.append(invite)
            invites.sort { $0.expiresAt < $1.expiresAt }
            return invite
        } catch {
            errorMessage = "Couldn't create the invite: \(error.localizedDescription)"
            return nil
        }
    }

    func cancel(_ invite: CaregiverInvite) async {
        do {
            try await repo.cancelInvite(code: invite.code)
            invites.removeAll { $0.code == invite.code }
        } catch {
            errorMessage = error.localizedDescription
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
