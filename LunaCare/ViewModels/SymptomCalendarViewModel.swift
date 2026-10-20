//
//  SymptomCalendarViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-09.
//  Updated by Mathew to show per-time symptom logs for a selected day and support local storage.
//

import Foundation


@MainActor
final class SymptomCalendarViewModel:
    ObservableObject {

    @Published var monthOffset:
        Int = 0

    @Published var selected:
        Date? = nil

    @Published var daysWithSymptoms:
        Set<Date> = []

    @Published var selectedEntries:
        [SymptomLogSummary] = []

    @Published var loadingMonth =
        false

    @Published var loadingSelected =
        false


    // Delete
    @Published var entryToDelete:
        SymptomLogSummary? = nil

    @Published var showingDeleteConfirmation =
        false

    @Published var deletingEntryId:
        String? = nil


    private let cal =
        Calendar.current

    private let repo:
        SymptomCalendarRepository

    private let localStore =
        LocalSymptomCalendarStore.shared

    private var syncManager =
        SyncManager.shared


    init(
        repo:
            SymptomCalendarRepository =
            SymptomCalendarRepository()
    ) {

        self.repo =
            repo

        self.syncManager =
            .shared
    }


    // MARK: - Computed

    var monthStart: Date {

        let base =
            cal.date(
                byAdding: .month,
                value: monthOffset,
                to: Date()
            )!


        return cal.date(
            from:
                cal.dateComponents(
                    [.year, .month],
                    from: base
                )
        )!
    }


    var monthTitle: String {

        let formatter =
            DateFormatter()

        formatter.dateFormat =
            "LLLL yyyy"

        return formatter.string(
            from:
                monthStart
        )
    }


    var weekdaySymbols:
        [String] {

        let formatter =
            DateFormatter()

        formatter.locale =
            .current

        return formatter
            .shortWeekdaySymbols
    }


    var daysGrid:
        [Date?] {

        let firstWeekday =
            cal.component(
                .weekday,
                from: monthStart
            )


        let leading =
            (firstWeekday + 6) % 7


        let days =
            cal.range(
                of: .day,
                in: .month,
                for: monthStart
            )!.count


        var array =
            Array<Date?>(
                repeating: nil,
                count: leading
            )


        for index in 0..<days {

            array.append(
                cal.date(
                    byAdding: .day,
                    value: index,
                    to: monthStart
                )!
            )
        }


        return array
    }


    func hasSymptoms(
        on day: Date?
    ) -> Bool {

        guard let day else {
            return false
        }


        let key =
            cal.startOfDay(
                for: day
            )


        return daysWithSymptoms
            .contains(key)
    }


    func isToday(
        _ day: Date?
    ) -> Bool {

        guard let day else {
            return false
        }


        return cal
            .isDateInToday(
                day
            )
    }


    var selectedTitle:
        String {

        guard let selected else {
            return "Select a day"
        }


        let formatter =
            DateFormatter()

        formatter.dateStyle =
            .medium

        formatter.timeStyle =
            .none


        return formatter.string(
            from:
                selected
        )
    }


    // MARK: - Load Month

    func loadMonth(
        for uid: String
    ) async {

        loadingMonth =
            true


        defer {
            loadingMonth =
                false
        }


        if !syncManager
            .isCloudSyncOn {

            daysWithSymptoms =
                localStore.fetchMonth(
                    monthStart:
                        monthStart
                )

        } else {

            do {

                daysWithSymptoms =
                    try await repo.fetchMonth(
                        uid: uid,
                        monthStart:
                            monthStart
                    )

            } catch {

                print(
                    "SymptomCalendarViewModel.loadMonth error: \(error.localizedDescription)"
                )
            }
        }


        if selected == nil {

            if cal.isDate(
                Date(),
                equalTo:
                    monthStart,
                toGranularity:
                    .month
            ) {

                selected =
                    Date()

            } else {

                selected =
                    daysWithSymptoms
                        .sorted()
                        .first
            }
        }


        if let selected {

            await select(
                day: selected,
                uid: uid
            )
        }
    }


    // MARK: - Change Month

    func changeMonth(
        by delta: Int,
        uid: String
    ) async {

        monthOffset +=
            delta


        await loadMonth(
            for: uid
        )
    }


    // MARK: - Select Day

    func select(
        day: Date,
        uid: String
    ) async {

        selected =
            day

        loadingSelected =
            true


        defer {
            loadingSelected =
                false
        }


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

            selectedEntries =
                []

            return
        }


        if !syncManager
            .isCloudSyncOn {

            selectedEntries =
                localStore
                    .fetchRange(
                        from: start,
                        to: end
                    )
                    .sorted {
                        $0.createdAt >
                        $1.createdAt
                    }

        } else {

            do {

                selectedEntries =
                    try await repo
                        .fetchRange(
                            uid: uid,
                            from: start,
                            to: end
                        )
                        .sorted {
                            $0.createdAt >
                            $1.createdAt
                        }

            } catch {

                print(
                    "SymptomCalendarViewModel.select error: \(error.localizedDescription)"
                )


                selectedEntries =
                    []
            }
        }
    }


    // MARK: - Request Delete

    func requestDelete(
        _ entry:
            SymptomLogSummary
    ) {

        entryToDelete =
            entry

        showingDeleteConfirmation =
            true
    }


    // MARK: - Delete

    func deleteSelectedEntry(
        uid: String
    ) async {

        guard let entry =
                entryToDelete
        else {
            return
        }


        deletingEntryId =
            entry.id


        defer {

            deletingEntryId =
                nil

            entryToDelete =
                nil
        }


        if !syncManager
            .isCloudSyncOn {

            LocalSymptomStore
                .shared
                .deleteOfflineSymptomLog(
                    createdAt:
                        entry.createdAt
                )

        } else {

            do {

                try await repo.deleteLog(
                    uid: uid,
                    logId:
                        entry.id
                )

            } catch {

                print(
                    "Unable to delete symptom log: \(error.localizedDescription)"
                )

                return
            }
        }


        // Reload calendar dots
        if !syncManager
            .isCloudSyncOn {

            daysWithSymptoms =
                localStore.fetchMonth(
                    monthStart:
                        monthStart
                )

        } else {

            do {

                daysWithSymptoms =
                    try await repo.fetchMonth(
                        uid: uid,
                        monthStart:
                            monthStart
                    )

            } catch {

                print(
                    "Failed to reload symptom month."
                )
            }
        }


        // Reload selected day
        if let selected {

            await select(
                day: selected,
                uid: uid
            )
        }
    }
}
