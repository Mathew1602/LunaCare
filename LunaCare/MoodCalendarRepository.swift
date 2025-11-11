//
//  MoodCalendarRepository.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-11.
//

import Foundation
import FirebaseFirestore

final class MoodCalendarRepository {

    func fetchMonth(uid: String, monthStart: Date) async throws -> [Date: Mood] {
        let cal = Calendar.current
        guard let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) else { return [:] }

        // Query this user's mood logs within [monthStart, monthEnd)
        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("mood_logs")
            .whereField("createdAt", isGreaterThanOrEqualTo: monthStart)
            .whereField("createdAt", isLessThan: monthEnd)
            .order(by: "createdAt", descending: true)

        let snapshot = try await ref.getDocuments()

        // For each calendar day, keep the *latest* mood
        var latestPerDay: [Date: Mood] = [:]
        for doc in snapshot.documents {
            guard
                let moodScore = doc.data()["mood"] as? Int,
                let ts = doc.data()["createdAt"] as? Timestamp
            else { continue }

            let dayStart = cal.startOfDay(for: ts.dateValue())
            if latestPerDay[dayStart] == nil {               // first seen = latest due to desc order
                latestPerDay[dayStart] = mapScoreToMood(moodScore)
            }
        }
        return latestPerDay
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
