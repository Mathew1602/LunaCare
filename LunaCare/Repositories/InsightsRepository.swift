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

    // MARK: - Save to Firestore
    func saveInsight(_ insight: WeeklyInsight) {
        var copy = insight
        copy.localOnly = false  // Firestore = cloud copy

        do {
            _ = try db.collection(FSPath.insights(uid))
                .addDocument(from: copy)
            print("Saved insight to Firestore")
        } catch {
            print("Failed saving insight: \(error.localizedDescription)")
        }
    }
}
