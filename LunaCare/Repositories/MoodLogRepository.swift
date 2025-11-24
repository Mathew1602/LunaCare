//
//  MoodLogRepository.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//  Updated by Xiaoya Zou, following MVVM

import Foundation
import FirebaseFirestore

protocol MoodLogsRepositoryType {

    func createMoodLog(
        uid: String,
        mood: Int,
        notes: String?,
        tags: [String]?,
        source: String?,
        createdAt: Date,
        completion: ((Error?) -> Void)?
    )

    func fetchMoodMonthRaw(uid: String, monthStart: Date) async throws -> [Date: Int]
}

final class MoodLogsRepository: MoodLogsRepositoryType {

    func createMoodLog(
        uid: String,
        mood: Int,
        notes: String?,
        tags: [String]?,
        source: String?,
        createdAt: Date,
        completion: ((Error?) -> Void)? = nil
    ) {
        var data: [String: Any] = [
            "mood": mood,
            "createdAt": createdAt,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let n = notes, !n.isEmpty { data["notes"] = n }
        if let t = tags,  !t.isEmpty { data["tags"]  = t }
        if let s = source, !s.isEmpty { data["source"] = s }

        FirestoreManager.shared.add(
            collectionPath: FSPath.moodLogs(uid),
            data: data
        ) { _, err in
            completion?(err)
        }
    }

    func fetchMoodMonthRaw(uid: String, monthStart: Date) async throws -> [Date: Int] {
        let cal = Calendar.current
        let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)!

        // Query: [users/{uid}/mood_logs] where createdAt in [monthStart, monthEnd)
        // Order by createdAt DESC so the first one we see for a given day is the latest.
        let query = Firestore.firestore()
            .collection("users").document(uid)
            .collection("mood_logs")
            .whereField("createdAt", isGreaterThanOrEqualTo: monthStart)
            .whereField("createdAt", isLessThan: monthEnd)
            .order(by: "createdAt", descending: true)

        let snap = try await query.getDocuments()
        var latestPerDay: [Date: Int] = [:]

        for doc in snap.documents {
            guard
                let score = doc["mood"] as? Int,
                let ts = doc["createdAt"] as? Timestamp
            else { continue }

            let day = cal.startOfDay(for: ts.dateValue())

            if latestPerDay[day] == nil {
                latestPerDay[day] = score
            }
        }
        return latestPerDay
    }
}
