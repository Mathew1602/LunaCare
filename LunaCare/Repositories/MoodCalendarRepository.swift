//
//  MoodCalendarRepository.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-11.
//

import Foundation
import FirebaseFirestore

final class MoodCalendarRepository {

    func fetchMonth(uid: String, monthStart: Date, source: FirestoreSource = .default) async throws -> [Date: [CalendarDayLog]] {
        let cal = Calendar.current
        guard let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) else { return [:] }

        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("mood_logs")
            .whereField("createdAt", isGreaterThanOrEqualTo: monthStart)
            .whereField("createdAt", isLessThan: monthEnd)
            .order(by: "createdAt", descending: true)

        let snapshot = try await ref.getDocuments(source: source)

        var grouped: [Date: [CalendarDayLog]] = [:]
        for doc in snapshot.documents {
            let data = doc.data()
            guard
                let score = data["mood"] as? Int,
                let ts = data["createdAt"] as? Timestamp
            else { continue }

            let note = data["notes"] as? String
            let created = ts.dateValue()
            let dayKey = cal.startOfDay(for: created)

            let item = CalendarDayLog(
                id: doc.documentID,
                mood: Mood(score: score),
                note: note,
                createdAt: created
            )
            grouped[dayKey, default: []].append(item)
        }
        return grouped
    }

    func fetchRange(uid: String, from: Date, to: Date) async throws -> [CalendarDayLog] {
        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("mood_logs")
            .whereField("createdAt", isGreaterThanOrEqualTo: from)
            .whereField("createdAt", isLessThanOrEqualTo: to)
            .order(by: "createdAt", descending: true)

        let snapshot = try await ref.getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard
                let score = data["mood"] as? Int,
                let ts = data["createdAt"] as? Timestamp
            else { return nil }

            return CalendarDayLog(
                id: doc.documentID,
                mood: Mood(score: score),
                note: data["notes"] as? String,
                createdAt: ts.dateValue()
            )
        }
    }

    func updateLog(
        uid: String,
        logId: String,
        newMood: Mood,
        newNote: String?
    ) async throws {
        var data: [String: Any] = [
            "mood": newMood.score,
            "updatedAt": Date()
        ]
        if let note = newNote, !note.isEmpty {
            data["notes"] = note
        } else {
            data["notes"] = FieldValue.delete()
        }

        try await FirestoreManager.shared.setDocument(path: "\(FSPath.moodLogs(uid))/\(logId)", data: data)
    }
    
    func deleteLog(uid: String, logId: String) async throws {
        try await FirestoreManager.shared.deleteDocument(path: "\(FSPath.moodLogs(uid))/\(logId)")
    }
}
