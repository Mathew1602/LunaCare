//
//  InsightService.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation

final class InsightService {
    /// Minimal rule: poor sleep + low mood -> insight
    func evaluateDaily(uid: String, recentMood: Int?, sleepMinutes: Int?, completion: ((Error?) -> Void)? = nil) {
        var texts: [String] = []
        if let m = recentMood, let s = sleepMinutes, s < 360 && m <= -1 {
            texts.append("Sleep may be impacting mood.")
        }
        guard let text = texts.first else { completion?(nil); return }

        let data: [String: Any] = [
            "kind": "daily",
            "text": text,
            "score": 0.6,
            "createdAt": Date()
        ]
        FirestoreManager.shared.add(collectionPath: FSPath.insights(uid), data: data) { _, err in
            completion?(err)
        }
    }
}
