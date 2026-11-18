//
//  CaregiverRepository.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-15.
//

import Foundation
import FirebaseFirestore

final class CaregiverRepository {

    private let db = Firestore.firestore()
    private let doctorRepo = DoctorRepository()

    /// Caregivers linked to the mother, merged with the permissions she granted each one.
    func fetchCaregivers(uid: String) async throws -> [Caregiver] {
        async let profileQuery = db.collection(FSPath.caregivers)
            .whereField("userIds", arrayContains: uid)
            .getDocuments()
        async let linkQuery = db.collection(FSPath.caregiverLinks(uid)).getDocuments()

        let (profiles, links) = try await (profileQuery, linkQuery)

        let permissionsById = Dictionary(uniqueKeysWithValues: links.documents.map { doc in
            (doc.documentID, CaregiverPermissions(data: doc.data()["permissions"] as? [String: Bool] ?? [:]))
        })

        return profiles.documents.compactMap { doc in
            let data = doc.data()
            guard let firstName = data["firstName"] as? String,
                  let lastName = data["lastName"] as? String else { return nil }
            return Caregiver(
                id: doc.documentID,
                firstName: firstName,
                lastName: lastName,
                email: data["email"] as? String ?? "",
                phone: data["phone"] as? String,
                permissions: permissionsById[doc.documentID] ?? CaregiverPermissions()
            )
        }
        .sorted { $0.lastName < $1.lastName }
    }

    /// Writes the grant. The caregiver can only read this doc, so the mother's name and
    /// (if shared) her doctors' contacts are copied here.
    func updatePermissions(uid: String, motherName: String, caregiverId: String, permissions: CaregiverPermissions) async throws {
        var data: [String: Any] = [
            "permissions": permissions.data,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if !motherName.isEmpty { data["motherName"] = motherName }
        if permissions.doctorContact {
            let doctors = try await doctorRepo.fetchDoctors(uid: uid)
            data["doctorContacts"] = doctors.map { DoctorContact(doctor: $0).data }
        } else {
            data["doctorContacts"] = FieldValue.delete()
        }

        try await db.collection(FSPath.caregiverLinks(uid)).document(caregiverId).setData(data, merge: true)
    }

    /// Unlinks the caregiver: removes the grant and the mother's uid from their profile.
    func remove(uid: String, caregiverId: String) async throws {
        let batch = db.batch()
        batch.deleteDocument(db.collection(FSPath.caregiverLinks(uid)).document(caregiverId))
        batch.updateData([
            "userIds": FieldValue.arrayRemove([uid])
        ], forDocument: db.collection(FSPath.caregivers).document(caregiverId))
        try await batch.commit()
    }

    // MARK: - Invites

    /// Creates a single-use invite. Rules only allow creating a new doc, so a code that's
    /// already taken is rejected and we retry with a fresh one.
    func createInvite(uid: String, email: String, relationship: String, permissions: CaregiverPermissions) async throws -> CaregiverInvite {
        let email = CaregiverInvite.normalizeEmail(email)
        let expiresAt = Date().addingTimeInterval(CaregiverInvite.lifetime)
        var attempt = 0
        while true {
            attempt += 1
            let invite = CaregiverInvite(code: CaregiverInvite.makeCode(), email: email, relationship: relationship,
                                         permissions: permissions, expiresAt: expiresAt)
            do {
                try await db.collection(FSPath.invites).document(invite.code).setData([
                    "motherUid": uid,
                    "email": email,
                    "relationship": relationship,
                    "permissions": permissions.data,
                    "createdAt": FieldValue.serverTimestamp(),
                    "expiresAt": Timestamp(date: expiresAt)
                ])
                return invite
            } catch {
                if attempt >= 3 { throw error }
            }
        }
    }

    /// The mother's invites that haven't expired, soonest to expire first.
    func fetchInvites(uid: String) async throws -> [CaregiverInvite] {
        let snapshot = try await db.collection(FSPath.invites)
            .whereField("motherUid", isEqualTo: uid)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue(), expiresAt > Date() else { return nil }
            return CaregiverInvite(
                code: doc.documentID,
                email: data["email"] as? String ?? "",
                relationship: data["relationship"] as? String ?? "",
                permissions: CaregiverPermissions(data: data["permissions"] as? [String: Bool] ?? [:]),
                expiresAt: expiresAt
            )
        }
        .sorted { $0.expiresAt < $1.expiresAt }
    }

    func cancelInvite(code: String) async throws {
        try await db.collection(FSPath.invites).document(code).delete()
    }
}
