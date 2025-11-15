//
//  SymptomCalendarRepository.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-14.
//

import Foundation
import FirebaseFirestore


struct SymptomDayDetail {
    let date: Date
    let values: [String: Int]
}

final class SymptomCalendarRepository {

    func fetchMonth(uid: String, monthStart: Date) async throws -> Set<Date> {
        let cal = Calendar.current
        guard let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
        }

        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("symptom_logs")
            .whereField("createdAt", isGreaterThanOrEqualTo: monthStart)
            .whereField("createdAt", isLessThan: monthEnd)
            .order(by: "createdAt", descending: true)

        let snapshot = try await ref.getDocuments()

        var days: Set<Date> = []
        for doc in snapshot.documents {
            guard let ts = doc.data()["createdAt"] as? Timestamp else { continue }
            let dayStart = cal.startOfDay(for: ts.dateValue())
            days.insert(dayStart)
        }
        return days
    }

    /// Latest symptom log for a specific day (returns the "values" dict).
    func fetchDay(uid: String, day: Date) async throws -> [String: Int]? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }

        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("symptom_logs")
            .whereField("createdAt", isGreaterThanOrEqualTo: start)
            .whereField("createdAt", isLessThan: end)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)

        let snap = try await ref.getDocuments()
        guard let doc = snap.documents.first else { return nil }

        // Firestore returns [String: Any]; convert to [String: Int]
        if let dict = doc.data()["values"] as? [String: Int] {
            return dict
        }

        if let anyDict = doc.data()["values"] as? [String: Any] {
            var result: [String: Int] = [:]
            for (k, v) in anyDict {
                if let n = v as? Int {
                    result[k] = n
                } else if let n = v as? NSNumber {
                    result[k] = n.intValue
                }
            }
            return result.isEmpty ? nil : result
        }

        return nil
    }
    
    func fetchDayValues(uid: String, day: Date) async throws -> [String: Int] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else {
            return [:]
        }

        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("symptom_logs")
            .whereField("createdAt", isGreaterThanOrEqualTo: dayStart)
            .whereField("createdAt", isLessThan: dayEnd)

        let snapshot = try await ref.getDocuments()

        var merged: [String: Int] = [:]

        for doc in snapshot.documents {
            guard let values = doc.data()["values"] as? [String: Int] else { continue }
            for (name, v) in values {
                // If multiple logs exist in one day, sum their values.
                merged[name, default: 0] += v
            }
        }

        return merged
    }
}
