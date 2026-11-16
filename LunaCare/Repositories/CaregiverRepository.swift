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

    func updatePermissions(uid: String, caregiverId: String, permissions: CaregiverPermissions) async throws {
        try await db.collection(FSPath.caregiverLinks(uid)).document(caregiverId).setData([
            "permissions": permissions.data,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
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
}
