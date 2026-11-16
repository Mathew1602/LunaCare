//
//  CaregiverReportRepository.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-16.
//

import Foundation
import FirebaseFirestore

/// Reads used by the signed-in caregiver. Every read here is gated by the mother's grant in the security rules.
final class CaregiverReportRepository {

    private let db = Firestore.firestore()

    /// The caregiver's own name, or nil if this user isn't a caregiver.
    func fetchCaregiverProfile(uid: String) async -> (firstName: String, lastName: String)? {
        guard !uid.isEmpty,
              let data = try? await db.collection(FSPath.caregivers).document(uid).getDocument().data()
        else { return nil }
        return (data["firstName"] as? String ?? "", data["lastName"] as? String ?? "")
    }

    func updateCaregiverProfile(uid: String, firstName: String, lastName: String) async throws {
        try await db.collection(FSPath.caregivers).document(uid).updateData([
            "firstName": firstName,
            "lastName": lastName,
            "displayName": "\(firstName) \(lastName)",
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Mothers this caregiver is linked to and still has an active grant from.
    func fetchLinkedMothers(caregiverUid: String) async throws -> [LinkedMother] {
        let profile = try await db.collection(FSPath.caregivers).document(caregiverUid).getDocument()
        let motherIds = profile.data()?["userIds"] as? [String] ?? []

        return try await withThrowingTaskGroup(of: LinkedMother?.self) { group in
            for motherId in motherIds {
                group.addTask { try await self.fetchGrant(motherUid: motherId, caregiverUid: caregiverUid) }
            }
            var mothers: [LinkedMother] = []
            for try await mother in group {
                if let mother { mothers.append(mother) }
            }
            return mothers.sorted { $0.name < $1.name }
        }
    }

    /// Daily reports for the last `days` days, newest first. Only shared collections are queried.
    func fetchReports(for mother: LinkedMother, days: Int) async throws -> [DailyReport] {
        let calendar = Calendar.current
        let since = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: Date()))!

        async let moods = mother.permissions.mood
            ? fetchDocuments(FSPath.moodLogs(mother.id), since: since) : []
        async let symptoms = mother.permissions.symptoms
            ? fetchDocuments(FSPath.symptomLogs(mother.id), since: since) : []

        var reports: [Date: DailyReport] = [:]

        // Documents are newest first, so keep the first mood seen per day.
        for (date, data) in try await moods {
            guard let score = data["mood"] as? Int else { continue }
            let day = calendar.startOfDay(for: date)
            if reports[day]?.mood == nil {
                reports[day, default: DailyReport(day: day)].mood = Mood(score: score)
            }
        }

        for (date, data) in try await symptoms {
            guard let values = data["values"] as? [String: Int] else { continue }
            let day = calendar.startOfDay(for: date)
            if reports[day]?.symptoms.isEmpty ?? true {
                reports[day, default: DailyReport(day: day)].symptoms = values
            }
        }

        return reports.values.sorted { $0.day > $1.day }
    }

    // MARK: - Private

    private func fetchGrant(motherUid: String, caregiverUid: String) async throws -> LinkedMother? {
        let doc = try await db.collection(FSPath.caregiverLinks(motherUid)).document(caregiverUid).getDocument()
        guard let data = doc.data() else { return nil }

        let contacts = (data["doctorContacts"] as? [[String: Any]] ?? []).compactMap(DoctorContact.init(data:))
        return LinkedMother(
            id: motherUid,
            name: data["motherName"] as? String ?? "Your loved one",
            permissions: CaregiverPermissions(data: data["permissions"] as? [String: Bool] ?? [:]),
            doctorContacts: contacts
        )
    }

    private func fetchDocuments(_ path: String, since: Date) async throws -> [(Date, [String: Any])] {
        let snapshot = try await db.collection(path)
            .whereField("createdAt", isGreaterThanOrEqualTo: since)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            guard let timestamp = doc["createdAt"] as? Timestamp else { return nil }
            return (timestamp.dateValue(), doc.data())
        }
    }
}
