//
//  FirestoreManager.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation
import FirebaseFirestore

final class FirestoreManager {
    static let shared = FirestoreManager()
    private init() {}
    private let db = Firestore.firestore()

    static let ackTimeout: TimeInterval = 8

    func write(path: String, data: [String: Any], merge: Bool = true, completion: ((Error?) -> Void)? = nil) {
        db.document(path).setData(data, merge: merge) { err in completion?(err) }
    }

    // Firestore only calls back once the server acknowledges a write, which never happens offline.
    // The write is already queued in the local cache, so after the timeout it is treated as saved.
    func setDocument(path: String, data: [String: Any], merge: Bool = true) async throws {
        let gate = ResumeGate()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.document(path).setData(data, merge: merge) { err in
                guard gate.claim() else { return }
                if let err { continuation.resume(throwing: err) } else { continuation.resume() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.ackTimeout) {
                guard gate.claim() else { return }
                continuation.resume()
            }
        }
    }

    func deleteDocument(path: String) async throws {
        let gate = ResumeGate()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.document(path).delete { err in
                guard gate.claim() else { return }
                if let err { continuation.resume(throwing: err) } else { continuation.resume() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.ackTimeout) {
                guard gate.claim() else { return }
                continuation.resume()
            }
        }
    }

    func get(path: String, completion: @escaping ([String: Any]?, Error?) -> Void) {
        db.document(path).getDocument { snap, err in
            completion(snap?.data(), err)
        }
    }
}

private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !claimed else { return false }
        claimed = true
        return true
    }
}
