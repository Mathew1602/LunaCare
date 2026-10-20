//
//  SymptomCalendarRepository.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-14.
//

import Foundation
import FirebaseFirestore


struct SymptomDayDetail {
    let date: Date
    let values: [String: Int]
}


final class SymptomCalendarRepository {

    // MARK: - Fetch Month

    func fetchMonth(
        uid: String,
        monthStart: Date
    ) async throws -> Set<Date> {

        let cal = Calendar.current

        guard let monthEnd =
                cal.date(
                    byAdding: .month,
                    value: 1,
                    to: monthStart
                )
        else {
            return []
        }


        let ref =
            Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection("symptom_logs")
                .whereField(
                    "createdAt",
                    isGreaterThanOrEqualTo:
                        monthStart
                )
                .whereField(
                    "createdAt",
                    isLessThan:
                        monthEnd
                )
                .order(
                    by: "createdAt",
                    descending: true
                )


        let snapshot =
            try await ref.getDocuments()


        var days: Set<Date> = []


        for doc in snapshot.documents {

            guard
                let timestamp =
                    doc.data()["createdAt"]
                    as? Timestamp
            else {
                continue
            }


            let dayStart =
                cal.startOfDay(
                    for:
                        timestamp.dateValue()
                )


            days.insert(
                dayStart
            )
        }


        return days
    }


    // MARK: - Fetch Day

    func fetchDay(
        uid: String,
        day: Date
    ) async throws -> [String: Int]? {

        let cal =
            Calendar.current


        let start =
            cal.startOfDay(
                for: day
            )


        guard let end =
                cal.date(
                    byAdding: .day,
                    value: 1,
                    to: start
                )
        else {
            return nil
        }


        let ref =
            Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection("symptom_logs")
                .whereField(
                    "createdAt",
                    isGreaterThanOrEqualTo:
                        start
                )
                .whereField(
                    "createdAt",
                    isLessThan:
                        end
                )
                .order(
                    by: "createdAt",
                    descending: true
                )
                .limit(to: 1)


        let snapshot =
            try await ref.getDocuments()


        guard let doc =
                snapshot.documents.first
        else {
            return nil
        }


        if let values =
            doc.data()["values"]
                as? [String: Int] {

            return values
        }


        if let values =
            doc.data()["values"]
                as? [String: Any] {

            var result:
                [String: Int] = [:]


            for (key, value) in values {

                if let number =
                    value as? Int {

                    result[key] =
                        number

                } else if let number =
                            value as? NSNumber {

                    result[key] =
                        number.intValue
                }
            }


            return result.isEmpty
                ? nil
                : result
        }


        return nil
    }


    // MARK: - Fetch Day Values

    func fetchDayValues(
        uid: String,
        day: Date
    ) async throws -> [String: Int] {

        let cal =
            Calendar.current


        let start =
            cal.startOfDay(
                for: day
            )


        guard let end =
                cal.date(
                    byAdding: .day,
                    value: 1,
                    to: start
                )
        else {
            return [:]
        }


        let snapshot =
            try await Firestore
                .firestore()
                .collection("users")
                .document(uid)
                .collection("symptom_logs")
                .whereField(
                    "createdAt",
                    isGreaterThanOrEqualTo:
                        start
                )
                .whereField(
                    "createdAt",
                    isLessThan:
                        end
                )
                .getDocuments()


        var merged:
            [String: Int] = [:]


        for doc in snapshot.documents {

            guard let values =
                    doc.data()["values"]
                    as? [String: Int]
            else {
                continue
            }


            for (name, value)
                in values {

                merged[name, default: 0] +=
                    value
            }
        }


        return merged
    }


    // MARK: - Fetch Range

    func fetchRange(
        uid: String,
        from: Date,
        to: Date
    ) async throws -> [SymptomLogSummary] {

        let ref =
            Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection("symptom_logs")
                .whereField(
                    "createdAt",
                    isGreaterThanOrEqualTo:
                        from
                )
                .whereField(
                    "createdAt",
                    isLessThan:
                        to
                )
                .order(
                    by: "createdAt",
                    descending: true
                )


        let snapshot =
            try await ref.getDocuments()


        var result:
            [SymptomLogSummary] = []


        for doc in snapshot.documents {

            let data =
                doc.data()


            guard let timestamp =
                    data["createdAt"]
                    as? Timestamp
            else {
                continue
            }


            let created =
                timestamp.dateValue()


            var values:
                [String: Int] = [:]


            if let dictionary =
                data["values"]
                    as? [String: Int] {

                values =
                    dictionary

            } else if let dictionary =
                        data["values"]
                        as? [String: Any] {

                for (key, value)
                    in dictionary {

                    if let number =
                        value as? Int {

                        values[key] =
                            number

                    } else if let number =
                                value as? NSNumber {

                        values[key] =
                            number.intValue
                    }
                }
            }


            let rows =
                values
                    .map {
                        SymptomRow(
                            name: $0.key,
                            value: $0.value
                        )
                    }
                    .sorted {
                        $0.value >
                        $1.value
                    }


            result.append(
                SymptomLogSummary(
                    id:
                        doc.documentID,
                    createdAt:
                        created,
                    rows:
                        rows
                )
            )
        }


        return result
    }


    // MARK: - Delete

    func deleteLog(
        uid: String,
        logId: String
    ) async throws {

        try await Firestore
            .firestore()
            .collection("users")
            .document(uid)
            .collection("symptom_logs")
            .document(logId)
            .delete()
    }
}
