//
//  InsightsRepository.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-30.
//

import Foundation
import FirebaseFirestore


final class InsightsRepository: ObservableObject {

    @Published var insights: [WeeklyInsight] = []

    private var listener: ListenerRegistration?
    private var isSyncing = false
    private let db = Firestore.firestore()
    private let uid: String

    init(uid: String) {
        self.uid = uid
        observeInsights()
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Live Firestore Listener
    private func observeInsights() {
        listener = db.collection(FSPath.insights(uid))
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("Error loading insights: \(error)")
                    return
                }

                guard let docs = snapshot?.documents else {
                    self.insights = []
                    return
                }

                self.insights = docs.compactMap { doc in
                    do {
                        var insight = try doc.data(as: WeeklyInsight.self)
                        insight.id = doc.documentID
                        insight.localOnly = false
                        return insight
                    } catch {
                        print("Insight decode error: \(error)")
                        return nil
                    }
                }
            }
    }

    // MARK: - Sync to Firestore
    @MainActor
    func syncInsights(_ generated: [WeeklyInsight]) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let collection = db.collection(FSPath.insights(uid))

        do {
            let existing = try await collection.getDocuments().documents.compactMap { doc -> (ref: DocumentReference, insight: WeeklyInsight)? in
                guard let insight = try? doc.data(as: WeeklyInsight.self) else { return nil }
                return (doc.reference, insight)
            }

            var duplicates: [DocumentReference] = []
            var latestByMetric: [String: WeeklyInsight] = [:]

            for group in Dictionary(grouping: existing, by: { $0.insight.metric }).values {
                var kept: WeeklyInsight?
                for entry in group.sorted(by: { $0.insight.createdAt < $1.insight.createdAt }) {
                    if let kept, Self.hasSameContent(kept, entry.insight) {
                        duplicates.append(entry.ref)
                    } else {
                        kept = entry.insight
                    }
                }
                if let kept { latestByMetric[kept.metric] = kept }
            }

            let toSave = generated.filter { insight in
                guard let latest = latestByMetric[insight.metric] else { return true }
                return !Self.hasSameContent(latest, insight)
            }

            var ops: [(WriteBatch) throws -> Void] = duplicates.map { ref in { $0.deleteDocument(ref) } }
            ops += toSave.map { insight in
                var copy = insight
                copy.localOnly = false
                return { try $0.setData(from: copy, forDocument: collection.document()) }
            }

            for start in stride(from: 0, to: ops.count, by: 500) {
                let batch = db.batch()
                for op in ops[start..<min(start + 500, ops.count)] {
                    try op(batch)
                }
                try await batch.commit()
            }

            print("Insights sync: \(toSave.count) saved, \(duplicates.count) duplicates removed")
        } catch {
            print("Failed syncing insights: \(error.localizedDescription)")
        }
    }

    private static func hasSameContent(_ a: WeeklyInsight, _ b: WeeklyInsight) -> Bool {
        a.metric == b.metric &&
        a.text == b.text &&
        a.last7Avg == b.last7Avg &&
        a.prev7Avg == b.prev7Avg &&
        a.direction == b.direction
    }
}
