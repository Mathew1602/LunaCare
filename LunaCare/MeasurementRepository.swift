//
//  MeasurementRepository.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation

final class MeasurementRepository {
    func upsert(uid: String, measurement: Measurement, completion: ((Error?) -> Void)? = nil) {
        var data: [String: Any] = [
            "date": measurement.date,
            "hrRest": measurement.hrRest as Any,
            "steps": measurement.steps as Any,
            "sleepMinutes": measurement.sleepMinutes as Any,
            "source": measurement.source as Any,
            "updatedAt": Date()
        ]
        if measurement.createdAt == nil { data["createdAt"] = Date() }

        let docId = measurement.id ?? UUID().uuidString
        let path = FSPath.measurements(uid) + "/\(docId)"
        FirestoreManager.shared.write(path: path, data: data, merge: true, completion: completion)
    }
}
