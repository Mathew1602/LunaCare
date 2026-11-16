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
    static func symptomLogs(_ uid: String) -> String { "users/\(uid)/symptom_logs" }
    static func insights(_ uid: String) -> String {
           "users/\(uid)/insights" }
    static let doctors = "doctors"
    static func doctorNotes(_ uid: String) -> String { "users/\(uid)/doctor_notes" }
    static let caregivers = "caregivers"
    /// Permissions the mother granted, one doc per caregiver uid.
    static func caregiverLinks(_ uid: String) -> String { "users/\(uid)/caregivers" }
    /// High PPD risk detections, one doc per day. Readable by caregivers granted `riskAlerts`.
    static func riskAlerts(_ uid: String) -> String { "users/\(uid)/alerts" }
    static let flContributions = "fl_contributions"
    static func snapshots(_ pid: String) -> String { "fl_contributions/\(pid)/snapshots" }


}
