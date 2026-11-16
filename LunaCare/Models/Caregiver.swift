//
//  Caregiver.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-15.
//

import Foundation

/// A family member linked to a mother. Profile lives in `caregivers/{caregiverUid}`.
struct Caregiver: Identifiable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let phone: String?
    var permissions: CaregiverPermissions

    var displayName: String { "\(firstName) \(lastName)" }
}

/// What the mother allows a caregiver to see. Stored in `users/{uid}/caregivers/{caregiverUid}`.
/// Missing keys default to `false`, matching the security rules (no grant = no access).
struct CaregiverPermissions: Hashable {
    var mood = false
    var symptoms = false
    var riskAlerts = false
    var doctorContact = false

    init(mood: Bool = false, symptoms: Bool = false, riskAlerts: Bool = false, doctorContact: Bool = false) {
        self.mood = mood
        self.symptoms = symptoms
        self.riskAlerts = riskAlerts
        self.doctorContact = doctorContact
    }

    init(data: [String: Bool]) {
        mood = data["mood"] ?? false
        symptoms = data["symptoms"] ?? false
        riskAlerts = data["riskAlerts"] ?? false
        doctorContact = data["doctorContact"] ?? false
    }

    var data: [String: Bool] {
        [
            "mood": mood,
            "symptoms": symptoms,
            "riskAlerts": riskAlerts,
            "doctorContact": doctorContact
        ]
    }
}
