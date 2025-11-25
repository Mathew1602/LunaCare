//
//  FirestorePaths.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//  Updated by Xiaoya Zou
//

import Foundation

enum FSPath {
    static func user(_ uid: String) -> String { "users/\(uid)" }

    /// User “meta” (profile, cloudSync, etc.) is stored on the root users/<uid> doc
    static func userMeta(_ uid: String) -> String { "users/\(uid)" }

    static func moodLogs(_ uid: String) -> String { "users/\(uid)/mood_logs" }
    static func DailyRecords(_ uid: String) -> String { "users/\(uid)/DailyRecords" }
    static func measurements(_ uid: String) -> String {"users/\(uid)/measurements"}
    static func insights(_ uid: String) -> String { "users/\(uid)/insights" }
    static func symptomLogs(_ uid: String) -> String { "users/\(uid)/symptom_logs" }
}
