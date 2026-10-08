//
//  Doctor.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-10-08.
//

import Foundation

struct Doctor: Identifiable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let specialty: String
    let organization: String
    let cpsoNumber: String
    let email: String
    let phone: String
    let accessLevel: String
    let isAuthorized: Bool
    let patientIds: [String]

    var displayName: String { "Dr. \(firstName) \(lastName)" }
}

struct DoctorComment: Identifiable, Hashable {
    let id: String
    let doctorId: String
    let doctorName: String
    let metric: String
    let dayKey: String?
    let text: String
    let createdAt: Date

    var metricTitle: String {
        if let healthMetric = HealthMetric(rawValue: metric) { return healthMetric.title }
        switch metric {
        case "mood": return "Mood"
        case "symptoms": return "Symptoms"
        default: return metric.capitalized
        }
    }

    var metricIcon: String {
        if let healthMetric = HealthMetric(rawValue: metric) { return healthMetric.icon }
        switch metric {
        case "mood": return "face.smiling"
        case "symptoms": return "cross.case"
        default: return "chart.bar"
        }
    }
}
