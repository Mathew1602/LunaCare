//
//  DoctorRepository.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-10-08.
//  Updated by xiaoya
//

import Foundation
import FirebaseFirestore

final class DoctorRepository {

    private let db = Firestore.firestore()

    func fetchDoctors(uid: String, includeUnauthorized: Bool = false) async throws -> [Doctor] {
        let doctors = try await fetchDoctors(uid: uid, field: "patientIds")
        return includeUnauthorized ? doctors : doctors.filter(\.isAuthorized)
    }

    func fetchPendingDoctors(uid: String) async throws -> [Doctor] {
        try await fetchDoctors(uid: uid, field: "pendingPatientIds")
    }

    func approve(uid: String, doctorId: String) async throws {
        let batch = db.batch()
        batch.updateData([
            "patientIds": FieldValue.arrayUnion([uid]),
            "pendingPatientIds": FieldValue.arrayRemove([uid])
        ], forDocument: db.collection(FSPath.doctors).document(doctorId))
        batch.setData([
            "doctorIds": FieldValue.arrayUnion([doctorId]),
            "pendingDoctorIds": FieldValue.arrayRemove([doctorId])
        ], forDocument: db.document(FSPath.user(uid)), merge: true)
        try await batch.commit()
    }

    func decline(uid: String, doctorId: String) async throws {
        let batch = db.batch()
        batch.updateData([
            "pendingPatientIds": FieldValue.arrayRemove([uid])
        ], forDocument: db.collection(FSPath.doctors).document(doctorId))
        batch.setData([
            "pendingDoctorIds": FieldValue.arrayRemove([doctorId])
        ], forDocument: db.document(FSPath.user(uid)), merge: true)
        try await batch.commit()
    }

    func revoke(uid: String, doctorId: String) async throws {
        let batch = db.batch()
        batch.updateData([
            "patientIds": FieldValue.arrayRemove([uid])
        ], forDocument: db.collection(FSPath.doctors).document(doctorId))
        batch.setData([
            "doctorIds": FieldValue.arrayRemove([doctorId])
        ], forDocument: db.document(FSPath.user(uid)), merge: true)
        try await batch.commit()
    }

    func fetchNotes(uid: String) async throws -> [DoctorNote] {
        let snapshot = try await db
            .collection(FSPath.doctorNotes(uid))
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()

            guard
                let text = data["text"] as? String,
                let timestamp = data["createdAt"] as? Timestamp
            else {
                return nil
            }

            // Support both old seeded notes and
            // new Doctor Portal notes.
            let doctorId =
                data["authorId"] as? String ??
                data["doctorId"] as? String ??
                ""

            let doctorName =
                data["authorName"] as? String ??
                data["doctorName"] as? String ??
                "Healthcare Provider"

            let metric =
                data["metric"] as? String ??
                "general"

            return DoctorNote(
                id: doc.documentID,
                doctorId: doctorId,
                doctorName: doctorName,
                metric: metric,
                dayKey: data["dayKey"] as? String,
                text: text,
                createdAt: timestamp.dateValue()
            )
        }
    }

    private func fetchDoctors(uid: String, field: String) async throws -> [Doctor] {
        let snapshot = try await db
            .collection(FSPath.doctors)
            .whereField(field, arrayContains: uid)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let firstName = data["firstName"] as? String,
                  let lastName = data["lastName"] as? String else { return nil }
            return Doctor(
                id: doc.documentID,
                firstName: firstName,
                lastName: lastName,
                specialty: data["specialty"] as? String ?? "",
                organization: data["organization"] as? String ?? "",
                cpsoNumber: data["cpsoNumber"] as? String ?? "",
                email: data["email"] as? String ?? "",
                phone: data["phone"] as? String ?? "",
                accessLevel: data["accessLevel"] as? String ?? "",
                isAuthorized: data["authorized"] as? Bool ?? false,
                patientIds: data["patientIds"] as? [String] ?? []
            )
        }
        .sorted { $0.lastName < $1.lastName }
    }
}
