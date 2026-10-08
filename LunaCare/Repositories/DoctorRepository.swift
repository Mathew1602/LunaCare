//
//  DoctorRepository.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-10-08.
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

    func fetchComments(uid: String) async throws -> [DoctorComment] {
        let snapshot = try await db
            .collection(FSPath.doctorComments(uid))
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let text = data["text"] as? String,
                  let ts = data["createdAt"] as? Timestamp else { return nil }
            return DoctorComment(
                id: doc.documentID,
                doctorId: data["doctorId"] as? String ?? "",
                doctorName: data["doctorName"] as? String ?? "",
                metric: data["metric"] as? String ?? "",
                dayKey: data["dayKey"] as? String,
                text: text,
                createdAt: ts.dateValue()
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
