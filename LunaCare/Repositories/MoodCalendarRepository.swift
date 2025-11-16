//
//  MoodCalendarRepository.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-11.
//
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

            let item = CalendarDayLog(
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
            guard let score = data["mood"] as? Int,
                  let ts = data["createdAt"] as? Timestamp else { return nil }

            return CalendarDayLog(
                mood: mapScoreToMood(score),
                note: data["notes"] as? String,
                createdAt: ts.dateValue()
            )
        }
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
}
