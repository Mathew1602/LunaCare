//
//  MoodLogRepository.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation

final class MoodLogRepository {
    func create(
        uid: String,
        mood: Int,
        notes: String?,
        tags: [String]?,
        source: String?,
        completion: ((Error?) -> Void)? = nil
    ) {
        let data: [String: Any] = [
            "mood": mood,
            "notes": notes as Any,
            "tags": tags as Any,
            "source": source as Any,
            "createdAt": Date(),
            "updatedAt": Date()
        ]
        FirestoreManager.shared.add(collectionPath: FSPath.moodLogs(uid), data: data) { _, err in
            completion?(err)
        }
    }
}
