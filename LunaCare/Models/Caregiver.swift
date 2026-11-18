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

// MARK: - Caregiver-side models

/// A mother the signed-in caregiver is linked to, with what she has shared.
struct LinkedMother: Identifiable, Hashable {
    let id: String
    let name: String
    let permissions: CaregiverPermissions
    let doctorContacts: [DoctorContact]
}

/// Contact info the mother chose to share. Copied into her grant doc because caregivers can't read `doctors`.
struct DoctorContact: Identifiable, Hashable {
    let id: String
    let name: String
    let specialty: String
    let phone: String
    let email: String

    init(id: String, name: String, specialty: String, phone: String, email: String) {
        self.id = id
        self.name = name
        self.specialty = specialty
        self.phone = phone
        self.email = email
    }

    init(doctor: Doctor) {
        self.init(id: doctor.id, name: doctor.displayName, specialty: doctor.specialty,
                  phone: doctor.phone, email: doctor.email)
    }

    init?(data: [String: Any]) {
        guard let id = data["id"] as? String, let name = data["name"] as? String else { return nil }
        self.init(id: id, name: name,
                  specialty: data["specialty"] as? String ?? "",
                  phone: data["phone"] as? String ?? "",
                  email: data["email"] as? String ?? "")
    }

    var data: [String: String] {
        ["id": id, "name": name, "specialty": specialty, "phone": phone, "email": email]
    }
}

/// One day of the mother's check-ins, limited to what she shared.
struct DailyReport: Identifiable, Hashable {
    let day: Date
    var mood: Mood?
    var symptoms: [String: Int] = [:]

    var id: Date { day }

    /// Symptoms she rated, strongest first.
    var reportedSymptoms: [(name: String, level: SymptomLevel)] {
        symptoms
            .compactMap { name, value in SymptomLevel(rawValue: value).map { (name, $0) } }
            .sorted { $0.level.rawValue > $1.level.rawValue }
    }
}

/// A high PPD risk detection from the mother's app. Stores no score, only that it happened.
struct RiskAlert: Identifiable, Hashable {
    let id: String
    let createdAt: Date
}

// MARK: - Invites

/// An invite for one email address. The caregiver is linked automatically when they sign in with
/// that email; the code is a backup they can enter by hand. Stored at `invites/{code}`.
struct CaregiverInvite: Identifiable, Hashable {
    static let codeLength = 6
    static let lifetime: TimeInterval = 48 * 60 * 60
    /// No look-alike characters (0/O, 1/I/L) so codes are easy to read aloud and type.
    private static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    let code: String
    let email: String
    let relationship: String
    let permissions: CaregiverPermissions
    let expiresAt: Date

    var id: String { code }

    /// "K7P2QX" → "K7P-2QX"
    var displayCode: String { "\(code.prefix(3))-\(code.suffix(3))" }

    var shareMessage: String {
        "I'd like you to support me on LunaCare. Sign up as a family caregiver with \(email) and you'll be linked to me automatically. If asked, enter code \(displayCode). It expires in 48 hours."
    }

    static func makeCode() -> String {
        String((0..<codeLength).map { _ in alphabet.randomElement()! })
    }

    /// Lowercased and trimmed, matching how Firebase Auth reports the caregiver's email.
    static func normalizeEmail(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isValidEmail(_ input: String) -> Bool {
        let email = normalizeEmail(input)
        guard let at = email.firstIndex(of: "@") else { return false }
        return at != email.startIndex && email[at...].contains(".") && !email.contains(" ")
    }

    /// Strips dashes/spaces and uppercases what the caregiver typed.
    static func normalize(_ input: String) -> String {
        input.uppercased().filter { $0.isLetter || $0.isNumber }
    }
}
