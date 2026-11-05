//
//  SymptomLogRepository.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-11.
//

import Foundation
import FirebaseFirestore

final class SymptomLogRepository {

    // One symptom record per day: the doc id is the day (users/{uid}/symptom_logs/2026-10-19),
    // so saving again on the same day replaces that day's record.
    func upsert(uid: String, log: LocalSymptomLog) async throws {
        let id = log.id ?? LocalSymptomLog.dayID(for: log.createdAt)
        var data: [String: Any] = [
            "values": log.payload.values,
            "createdAt": log.createdAt,
            "updatedAt": log.updatedAt ?? log.createdAt,
            "dayKey": LocalSymptomLog.dayID(for: log.createdAt)
        ]
        if let n = log.payload.notes, !n.isEmpty  { data["notes"] = n }
        if let t = log.payload.tags,  !t.isEmpty  { data["tags"] = t }
        if let s = log.payload.source, !s.isEmpty { data["source"] = s }

        try await FirestoreManager.shared.setDocument(path: "\(FSPath.symptomLogs(uid))/\(id)", data: data, merge: false)
    }
}
