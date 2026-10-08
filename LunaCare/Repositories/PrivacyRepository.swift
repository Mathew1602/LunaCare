//
//  PrivacyRepository.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-10-08.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

struct ConsentSettings: Equatable {
    var shareWithDoctors = true
    var riskInsights = true
    var updatedAt: Date? = nil
}

enum ConsentKey: String {
    case shareWithDoctors, riskInsights
}

final class PrivacyRepository {

    static let countedCollections = ["mood_logs", "symptom_logs", "measurements", "insights", "doctor_comments"]
    private static let deletableCollections = ["measurements", "mood_logs", "symptom_logs", "insights", "DailyRecords", "doctor_comments"]

    private let db = Firestore.firestore()
    private let doctorRepo = DoctorRepository()

    func fetchCounts(uid: String) async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        try await withThrowingTaskGroup(of: (String, Int).self) { group in
            for name in Self.countedCollections {
                group.addTask {
                    let snapshot = try await self.db.document(FSPath.user(uid)).collection(name)
                        .count.getAggregation(source: .server)
                    return (name, snapshot.count.intValue)
                }
            }
            for try await (name, count) in group {
                counts[name] = count
            }
        }
        return counts
    }

    func fetchConsent(uid: String) async throws -> ConsentSettings {
        let data = try await db.document(FSPath.user(uid)).getDocument().data() ?? [:]
        let consent = data["consent"] as? [String: Bool] ?? [:]
        return ConsentSettings(
            shareWithDoctors: consent[ConsentKey.shareWithDoctors.rawValue] ?? true,
            riskInsights: consent[ConsentKey.riskInsights.rawValue] ?? true,
            updatedAt: (data["consentUpdatedAt"] as? Timestamp)?.dateValue()
        )
    }

    func setConsent(uid: String, key: ConsentKey, value: Bool) async throws {
        try await db.document(FSPath.user(uid)).setData([
            "consent": [key.rawValue: value],
            "consentUpdatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func deleteAccount(password: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw NSError(domain: "PrivacyRepository", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No signed-in account found."])
        }
        let uid = user.uid

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        do {
            try await user.reauthenticate(with: credential)
        } catch {
            let code = (error as NSError).code
            if code == AuthErrorCode.wrongPassword.rawValue || code == AuthErrorCode.invalidCredential.rawValue {
                throw NSError(domain: "PrivacyRepository", code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "Incorrect password. Please try again."])
            }
            throw error
        }

        for doctor in try await doctorRepo.fetchDoctors(uid: uid, includeUnauthorized: true) {
            try await doctorRepo.revoke(uid: uid, doctorId: doctor.id)
        }
        for doctor in try await doctorRepo.fetchPendingDoctors(uid: uid) {
            try await doctorRepo.decline(uid: uid, doctorId: doctor.id)
        }

        let userRef = db.document(FSPath.user(uid))
        for name in Self.deletableCollections {
            let docs = try await userRef.collection(name).getDocuments().documents
            for start in stride(from: 0, to: docs.count, by: 400) {
                let batch = db.batch()
                docs[start..<min(start + 400, docs.count)].forEach { batch.deleteDocument($0.reference) }
                try await batch.commit()
            }
        }
        try await userRef.delete()
        try await user.delete()

        clearLocalData()
    }

    private func clearLocalData() {
        LocalMeasurementStore.shared.clearAll()
        LocalMoodCalendarStore.shared.clearAll()
        LocalMoodStore.shared.clearOfflineMoods()
        LocalSymptomStore.shared.clearOfflineSymptomLogs()
        LocalStorageInsights.shared.save([])
        UserDefaults.standard.removeObject(forKey: "home_metrics")
        UserDefaults.standard.removeObject(forKey: "pendingHealthUploadDays")
    }
}
