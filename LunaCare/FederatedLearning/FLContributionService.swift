//
//  FLContributionService.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-10-11.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Uploads one pseudonymous 30-day feature snapshot per week for users who opted in
/// (users/{uid}.consent.contributeToModel). No uid, email or name is written.
final class FLContributionService {

    static let shared = FLContributionService()

    private let lastUploadKeyPrefix = "fl_lastUploadAt_"
    private let uploadInterval: TimeInterval = 7 * 24 * 60 * 60
    private let minDaysWithData = 14
    private let maxSnapshots = 12

    private let db = Firestore.firestore()
    private let pipeline = PPDFeaturePipeline()
    private let windowLoader = PPDWindowLoader()

    private init() {}

    func uploadIfDue(force: Bool = false) async {
        do {
            try await upload(force: force)
        } catch {
            print("[FL] upload failed: \(error.localizedDescription)")
        }
    }

    func deleteAll(uid: String) async throws {
        guard let pid = try await pseudoId(uid: uid) else { return }

        let docs = try await db.collection(FSPath.snapshots(pid)).getDocuments().documents
        try await delete(docs.map(\.reference))
        try await db.collection(FSPath.flContributions).document(pid).delete()
        UserDefaults.standard.removeObject(forKey: lastUploadKey(uid))
    }

    private func lastUploadKey(_ uid: String) -> String { lastUploadKeyPrefix + uid }

    private func upload(force: Bool) async throws {
        guard let user = Auth.auth().currentUser, !user.isAnonymous else { return }
        if !force, let last = UserDefaults.standard.object(forKey: lastUploadKey(user.uid)) as? Date,
           Date().timeIntervalSince(last) < uploadInterval {
            return
        }

        let userData = try await db.document(FSPath.user(user.uid)).getDocument().data() ?? [:]
        let consent = userData["consent"] as? [String: Bool] ?? [:]
        guard consent[ConsentKey.contributeToModel.rawValue] == true,
              let pid = userData["flPseudoId"] as? String else { return }

        let now = Date()
        let cal = Calendar.current
        let windowEnd = cal.startOfDay(for: now)
        let windowStart = cal.date(byAdding: .day, value: -(PPDFeaturePipeline.windowDays - 1), to: windowEnd) ?? windowEnd

        let records = try await windowLoader.load(uid: user.uid,
                                                  fromCloud: UserDefaults.standard.bool(forKey: "cloudSyncEnabled"),
                                                  windowEnd: now)

        let daysWithData = pipeline.daysWithData(records, windowEnd: now)
        guard daysWithData >= minDaysWithData else {
            print("[FL] skipped: \(daysWithData) days with data (< \(minDaysWithData))")
            return
        }

        let features = pipeline.rawFeatures(from: records, windowEnd: now)
            .mapValues { $0.map { $0 as Any } ?? NSNull() }

        let parentRef = db.collection(FSPath.flContributions).document(pid)
        let snapshotRef = db.collection(FSPath.snapshots(pid)).document(Measurement(createdAt: now).dayKey)

        var parent: [String: Any] = [
            "lastUploadAt": FieldValue.serverTimestamp(),
            "featureSchemaVersion": PPDFeaturePipeline.featureSchemaVersion
        ]
        if try await !parentRef.getDocument().exists {
            parent["createdAt"] = FieldValue.serverTimestamp()
        }

        let batch = db.batch()
        batch.setData(parent, forDocument: parentRef, merge: true)
        batch.setData([
            "features": features,
            "daysWithData": daysWithData,
            "windowStart": Timestamp(date: windowStart),
            "windowEnd": Timestamp(date: now),
            "featureSchemaVersion": PPDFeaturePipeline.featureSchemaVersion,
            "appModelVersion": ModelUpdateService.currentVersion
        ], forDocument: snapshotRef)
        try await batch.commit()

        UserDefaults.standard.set(now, forKey: lastUploadKey(user.uid))
        try await trimSnapshots(pid: pid)
    }

    private func trimSnapshots(pid: String) async throws {
        let docs = try await db.collection(FSPath.snapshots(pid)).getDocuments().documents
            .sorted { $0.documentID < $1.documentID }
        guard docs.count > maxSnapshots else { return }
        try await delete(docs.prefix(docs.count - maxSnapshots).map(\.reference))
    }

    private func pseudoId(uid: String) async throws -> String? {
        try await db.document(FSPath.user(uid)).getDocument().data()?["flPseudoId"] as? String
    }

    private func delete(_ refs: [DocumentReference]) async throws {
        for start in stride(from: 0, to: refs.count, by: 400) {
            let batch = db.batch()
            refs[start..<min(start + 400, refs.count)].forEach { batch.deleteDocument($0) }
            try await batch.commit()
        }
    }
}
