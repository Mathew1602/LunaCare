//
//  MoodCalendarRepository.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-11.
//
import Foundation
import FirebaseFirestore

final class MoodCalendarRepository {

    func fetchMonth(uid: String, monthStart: Date) async throws -> [Date: [CalendarDayLog]] {
        let cal = Calendar.current
        guard let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) else { return [:] }

        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("mood_logs")
            .whereField("createdAt", isGreaterThanOrEqualTo: monthStart)
            .whereField("createdAt", isLessThan: monthEnd)
            .order(by: "createdAt", descending: true)

        let snapshot = try await ref.getDocuments()

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

            // Use Firestore document ID as the CalendarDayLog.id
            let item = CalendarDayLog(
                id: doc.documentID,
                mood: mapScoreToMood(score),
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
                mood: mapScoreToMood(score),
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
        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("mood_logs")
            .document(logId)

        var data: [String: Any] = [
            "mood": mapMoodToScore(newMood),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let note = newNote, !note.isEmpty {
            data["notes"] = note
        } else {
            // Clear the notes field if empty
            data["notes"] = FieldValue.delete()
        }

        try await ref.updateData(data)
    }

    private func mapScoreToMood(_ s: Int) -> Mood {
        switch s {
        case 4:  return .ecstatic
        case 2:  return .happy
        case 0:  return .okay
        case -1: return .sad
        case -2: return .angry
        default: return .okay
        }
    }

    private func mapMoodToScore(_ mood: Mood) -> Int {
        switch mood {
        case .ecstatic: return 4
        case .happy:    return 2
        case .okay:     return 0
        case .sad:      return -1
        case .angry:    return -2
        }
    }
}
