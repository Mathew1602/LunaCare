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

    func write(path: String, data: [String: Any], merge: Bool = true, completion: ((Error?) -> Void)? = nil) {
        db.document(path).setData(data, merge: merge) { err in completion?(err) }
    }

    func add(collectionPath: String, data: [String: Any], completion: ((String?, Error?) -> Void)? = nil) {
        var ref: DocumentReference?
        ref = db.collection(collectionPath).addDocument(data: data) { err in
            completion?(err == nil ? ref?.documentID : nil, err)
        }
    }

    func get(path: String, completion: @escaping ([String: Any]?) -> Void) {
        db.document(path).getDocument { snap, _ in
            completion(snap?.data())
        }
    }
}

