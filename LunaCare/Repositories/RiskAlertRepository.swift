//
//  RiskAlertRepository.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-16.
//

import Foundation
import FirebaseFirestore

/// `users/{uid}/alerts`: written by the mother's app, read by caregivers she granted `riskAlerts`.
final class RiskAlertRepository {

    private let db = Firestore.firestore()

    /// One doc per day, so repeated detections on the same day don't create duplicates.
    func recordHighRisk(uid: String, at date: Date = Date()) async throws {
        let dayKey = LocalSymptomLog.dayID(for: date)
        try await db.collection(FSPath.riskAlerts(uid)).document(dayKey).setData([
            "tier": PPDRiskTier.high.rawValue,
            "dayKey": dayKey,
            "createdAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func fetchAlerts(motherUid: String, days: Int) async throws -> [RiskAlert] {
        let since = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let snapshot = try await db.collection(FSPath.riskAlerts(motherUid))
            .whereField("createdAt", isGreaterThanOrEqualTo: since)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            guard let timestamp = doc["createdAt"] as? Timestamp else { return nil }
            return RiskAlert(id: doc.documentID, createdAt: timestamp.dateValue())
        }
    }
}
