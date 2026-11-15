//
//  MoodLogRepository.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//  Updated by Xiaoya Zou, following MVVM

import Foundation
import FirebaseFirestore

protocol MoodLogsRepositoryType {

    func upsertMoodLog(_ log: MoodLog, uid: String) async throws

    func fetchMoodMonthRaw(uid: String, monthStart: Date) async throws -> [Date: Int]
}

final class MoodLogsRepository: MoodLogsRepositoryType {

    func upsertMoodLog(_ log: MoodLog, uid: String) async throws {
        let id = log.id ?? UUID().uuidString
        var data: [String: Any] = [
            "mood": log.mood,
            "createdAt": log.createdAt ?? Date(),
            "updatedAt": log.updatedAt ?? Date()
        ]
        data["notes"] = (log.notes?.isEmpty == false) ? log.notes! : FieldValue.delete()
        if let t = log.tags, !t.isEmpty { data["tags"] = t }
        if let s = log.source, !s.isEmpty { data["source"] = s }

        try await FirestoreManager.shared.setDocument(path: "\(FSPath.moodLogs(uid))/\(id)", data: data)
    }

    func fetchMoodMonthRaw(uid: String, monthStart: Date) async throws -> [Date: Int] {
        let cal = Calendar.current
        let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)!

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
