//
//  MoodCalendarViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-11.
//  Updated by Mathew to support editing existing mood logs and local storage.
//

import Foundation


@MainActor
final class MoodCalendarViewModel: ObservableObject {

    @Published var monthOffset: Int = 0
    @Published var selected: Date? = nil

    @Published var logsByDay: [Date: [CalendarDayLog]] = [:]

    @Published var loading: Bool = false
    @Published var errorText: String? = nil


    // MARK: - Editing

    @Published var editingLog: CalendarDayLog? = nil
    @Published var editingMood: Mood = .okay
    @Published var editingNote: String = ""
    @Published var isSavingEdit: Bool = false


    // MARK: - Delete

    @Published var logToDelete: CalendarDayLog? = nil
    @Published var showingDeleteConfirmation = false
    @Published var isDeleting = false


    private let cal = Calendar.current

    private let repo: MoodCalendarRepository

    private let localStore =
        LocalMoodCalendarStore.shared

    private var syncManager =
        SyncManager.shared


    init(
        repo: MoodCalendarRepository =
            MoodCalendarRepository()
    ) {

        self.repo = repo
        self.syncManager = .shared
    }


    // MARK: - Month

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
            from: monthStart
        )
    }


    var weekdaySymbols: [String] {

        let formatter =
            DateFormatter()

        formatter.locale =
            .current

        return formatter
            .shortWeekdaySymbols
    }


    var daysGrid: [Date?] {

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


        for i in 0..<days {

            array.append(
                cal.date(
                    byAdding: .day,
                    value: i,
                    to: monthStart
                )!
            )
        }


        return array
    }


    // MARK: - Navigation

    func setMonth(
        delta: Int,
        uid: String
    ) async {

        monthOffset += delta

        await load(
            uid: uid
        )
    }


    // MARK: - Load

    func load(
        uid: String
    ) async {

        loading = true
        errorText = nil


        if !syncManager.isCloudSyncOn {

            logsByDay =
                localStore.fetchMonth(
                    monthStart:
                        monthStart
                )


            print(
                "MoodCalendarViewModel: loaded \(logsByDay.count) days from local store."
            )

        } else {

            do {

                let map =
                    try await repo.fetchMonth(
                        uid: uid,
                        monthStart:
                            monthStart
                    )


                logsByDay =
                    map

            } catch {

                errorText =
                    "Failed to load: \(error.localizedDescription)"


                print(
                    "MoodCalendarViewModel.load error: \(error.localizedDescription)"
                )
            }
        }


        loading = false


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
                    logsByDay
                        .keys
                        .sorted()
                        .first
            }
        }
    }


    // MARK: - Helpers

    func latestMood(
        for day: Date?
    ) -> Mood? {

        guard let day else {
            return nil
        }


        return logsByDay[
            cal.startOfDay(
                for: day
            )
        ]?
        .first?
        .mood
    }


    func logsForSelected()
        -> [CalendarDayLog] {

        guard let selected else {
            return []
        }


        return logsByDay[
            cal.startOfDay(
                for: selected
            )
        ] ?? []
    }


    // MARK: - Editing

    func beginEdit(
        log: CalendarDayLog
    ) {

        editingLog =
            log

        editingMood =
            log.mood

        editingNote =
            log.note ?? ""
    }


    func saveEdit(
        uid: String
    ) async {

        guard let log =
            editingLog
        else {
            return
        }


        isSavingEdit =
            true


        defer {
            isSavingEdit =
                false
        }


        if !syncManager.isCloudSyncOn {

            localStore.updateLog(
                logId:
                    log.id,
                newMood:
                    editingMood,
                newNote:
                    editingNote
            )


            let updatedMoodLog =
                MoodLog(
                    id:
                        log.id,
                    mood:
                        editingMood.score,
                    notes:
                        editingNote
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                        ? nil
                        : editingNote
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            ),
                    tags:
                        ["manual"],
                    source:
                        "manual",
                    createdAt:
                        log.createdAt
                )


            LocalMoodStore.shared
                .saveOfflineMood(
                    updatedMoodLog
                )


            print(
                "Mood edit saved locally for log id: \(log.id)"
            )


            await load(
                uid: uid
            )

        } else {

            do {

                try await repo.updateLog(
                    uid: uid,
                    logId:
                        log.id,
                    newMood:
                        editingMood,
                    newNote:
                        editingNote
                )


                await load(
                    uid: uid
                )

            } catch {

                print(
                    "MoodCalendarViewModel.saveEdit error: \(error.localizedDescription)"
                )
            }
        }


        editingLog =
            nil
    }


    // MARK: - Delete

    func requestDelete(
        log: CalendarDayLog
    ) {

        logToDelete =
            log

        showingDeleteConfirmation =
            true
    }


    func deleteLog(
        uid: String
    ) async {

        guard let log =
            logToDelete
        else {
            return
        }


        isDeleting =
            true


        defer {

            isDeleting =
                false

            logToDelete =
                nil
        }


        if !syncManager.isCloudSyncOn {

            // Delete calendar copy
            localStore.deleteLog(
                logId:
                    log.id
            )


            print(
                "Mood log deleted locally: \(log.id)"
            )


            await load(
                uid: uid
            )

        } else {

            do {

                try await repo.deleteLog(
                    uid: uid,
                    logId:
                        log.id
                )


                print(
                    "Mood log deleted from Firebase: \(log.id)"
                )


                await load(
                    uid: uid
                )

            } catch {

                errorText =
                    "Unable to delete mood entry: \(error.localizedDescription)"


                print(
                    "MoodCalendarViewModel.deleteLog error: \(error.localizedDescription)"
                )
            }
        }
    }
}
