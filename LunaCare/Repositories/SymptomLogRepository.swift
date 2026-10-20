//
//  SymptomLogRepository.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-11.
//

import Foundation
import FirebaseFirestore


final class SymptomLogRepository {

    private var db: Firestore {
        Firestore.firestore()
    }


    // =========================================================
    // MARK: - Create / Update with specific date
    //
    // One symptom record is stored per day.
    //
    // If a record already exists for this date,
    // it will be overwritten.
    // =========================================================

    func create(
        uid: String,
        payload: SymptomLogPayload,
        createdAt: Date,
        completion: ((Error?) -> Void)? = nil
    ) {

        let documentId =
            dayDocumentId(
                from: createdAt
            )


        var data: [String: Any] = [

            "values":
                payload.values,

            "createdAt":
                createdAt,

            "updatedAt":
                FieldValue.serverTimestamp(),

            "dayKey":
                documentId
        ]


        if let notes = payload.notes,
           !notes.isEmpty {

            data["notes"] =
                notes
        }


        if let tags = payload.tags,
           !tags.isEmpty {

            data["tags"] =
                tags
        }


        if let source = payload.source,
           !source.isEmpty {

            data["source"] =
                source
        }


        saveDailyRecord(
            uid: uid,
            documentId: documentId,
            data: data,
            completion: completion
        )
    }


    // =========================================================
    // MARK: - Create / Update for today
    //
    // Used when no custom date is provided.
    // =========================================================

    func create(
        uid: String,
        payload: SymptomLogPayload,
        completion: ((Error?) -> Void)? = nil
    ) {

        let now =
            Date()


        let documentId =
            dayDocumentId(
                from: now
            )


        var data: [String: Any] = [

            "values":
                payload.values,

            // We use the current time so the Calendar can
            // show when today's symptoms were last entered.
            "createdAt":
                now,

            "updatedAt":
                FieldValue.serverTimestamp(),

            "dayKey":
                documentId
        ]


        if let notes = payload.notes,
           !notes.isEmpty {

            data["notes"] =
                notes
        }


        if let tags = payload.tags,
           !tags.isEmpty {

            data["tags"] =
                tags
        }


        if let source = payload.source,
           !source.isEmpty {

            data["source"] =
                source
        }


        saveDailyRecord(
            uid: uid,
            documentId: documentId,
            data: data,
            completion: completion
        )
    }


    // =========================================================
    // MARK: - Create / Update from SymptomEntry array
    //
    // This is the version currently used by
    // SymptomTrackingViewModel.
    // =========================================================

    func create(
        uid: String,
        entries: [SymptomEntry],
        notes: String? = nil,
        tags: [String]? = nil,
        source: String? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {

        let values =
            Dictionary(
                uniqueKeysWithValues:
                    entries.map {
                        (
                            $0.name,
                            Int($0.value)
                        )
                    }
            )


        let payload =
            SymptomLogPayload(
                values: values,
                notes: notes,
                tags: tags,
                source: source
            )


        create(
            uid: uid,
            payload: payload,
            completion: completion
        )
    }


    // =========================================================
    // MARK: - Save Daily Record
    //
    // IMPORTANT:
    //
    // setData() uses the date as the document ID.
    //
    // Example:
    //
    // users/{uid}/symptom_logs/2026-10-19
    //
    // Saving again on the same day writes to the SAME
    // document instead of adding another one.
    // =========================================================

    private func saveDailyRecord(
        uid: String,
        documentId: String,
        data: [String: Any],
        completion: ((Error?) -> Void)? = nil
    ) {

        db
            .collection("users")
            .document(uid)
            .collection("symptom_logs")
            .document(documentId)
            .setData(
                data,
                merge: false
            ) { error in

                completion?(
                    error
                )
            }
    }


    // =========================================================
    // MARK: - Daily Document ID
    //
    // Converts:
    //
    // October 19, 2026
    //
    // into:
    //
    // 2026-10-19
    //
    // =========================================================

    private func dayDocumentId(
        from date: Date
    ) -> String {

        let formatter =
            DateFormatter()


        formatter.locale =
            Locale(
                identifier:
                    "en_US_POSIX"
            )


        formatter.timeZone =
            .current


        formatter.dateFormat =
            "yyyy-MM-dd"


        return formatter.string(
            from: date
        )
    }
}
