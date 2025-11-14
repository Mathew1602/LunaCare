//
//  SymptomLogRepository.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-11.
//

import Foundation
import FirebaseFirestore

struct SymptomLogPayload {
    let values: [String: Int]      // e.g., ["Fatigue": 6, "Bleeding": 2, ...]
    let notes: String?
    let tags: [String]?
    let source: String?
}

final class SymptomLogRepository {

    func create(
        uid: String,
        payload: SymptomLogPayload,
        completion: ((Error?) -> Void)? = nil
    ) {
        var data: [String: Any] = [
            "values": payload.values,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let n = payload.notes, !n.isEmpty  { data["notes"] = n }
        if let t = payload.tags,  !t.isEmpty  { data["tags"] = t }
        if let s = payload.source, !s.isEmpty { data["source"] = s }

        FirestoreManager.shared.add(collectionPath: FSPath.symptomLogs(uid), data: data) { _, err in
            completion?(err)
        }
    }

    func create(
        uid: String,
        entries: [SymptomEntry],
        notes: String? = nil,
        tags: [String]? = nil,
        source: String? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        let dict = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, Int($0.value)) })
        let payload = SymptomLogPayload(values: dict, notes: notes, tags: tags, source: source)
        create(uid: uid, payload: payload, completion: completion)
    }
}

