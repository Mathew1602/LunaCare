//  MoodCalendarViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-11.
//  Updated by Mathew to support editing existing mood logs.
//

import Foundation

@MainActor
final class MoodCalendarViewModel: ObservableObject {

    @Published var monthOffset: Int = 0
    @Published var selected: Date? = nil

    @Published var logsByDay: [Date: [CalendarDayLog]] = [:]
    @Published var loading: Bool = false
    @Published var errorText: String? = nil

    // Editing state
    @Published var editingLog: CalendarDayLog? = nil
    @Published var editingMood: Mood = .okay
    @Published var editingNote: String = ""
    @Published var isSavingEdit: Bool = false

    private let cal = Calendar.current
    private let repo: MoodCalendarRepository

    init(repo: MoodCalendarRepository = MoodCalendarRepository()) {
        self.repo = repo
    }


    var monthStart: Date {
        let base = cal.date(byAdding: .month, value: monthOffset, to: Date())!
        return cal.date(from: cal.dateComponents([.year, .month], from: base))!
    }

    var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: monthStart)
    }

    var weekdaySymbols: [String] {
        let f = DateFormatter()
        f.locale = .current
        return f.shortWeekdaySymbols
    }

    var daysGrid: [Date?] {
        let firstWeekday = cal.component(.weekday, from: monthStart)
        let leading = (firstWeekday + 6) % 7
        let days = cal.range(of: .day, in: .month, for: monthStart)!.count
        var arr = Array<Date?>(repeating: nil, count: leading)
        for i in 0..<days {
            arr.append(cal.date(byAdding: .day, value: i, to: monthStart)!)
        }
        return arr
    }


    @MainActor
    func setMonth(delta: Int, uid: String) async {
        monthOffset += delta
        await load(uid: uid)
    }

    func load(uid: String) async {
        guard !uid.isEmpty else { return }
        await MainActor.run {
            loading = true
            errorText = nil
        }
        do {
            let map = try await repo.fetchMonth(uid: uid, monthStart: monthStart)
            await MainActor.run {
                self.logsByDay = map
                self.loading = false

                // Ensure a selected day (defaults to today if in this month)
                if self.selected == nil {
                    if self.cal.isDate(Date(), equalTo: self.monthStart, toGranularity: .month) {
                        self.selected = Date()
                    } else {
                        self.selected = self.logsByDay.keys.sorted().first
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.loading = false
                self.errorText = "Failed to load: \(error.localizedDescription)"
            }
        }
    }

    func latestMood(for day: Date?) -> Mood? {
        guard let day else { return nil }
        return logsByDay[cal.startOfDay(for: day)]?.first?.mood
    }

    func logsForSelected() -> [CalendarDayLog] {
        guard let s = selected else { return [] }
        return logsByDay[cal.startOfDay(for: s)] ?? []
    }


    func beginEdit(log: CalendarDayLog) {
        editingLog = log
        editingMood = log.mood
        editingNote = log.note ?? ""
    }

    func saveEdit(uid: String) async {
        guard let log = editingLog else { return }
        isSavingEdit = true
        defer { isSavingEdit = false }

        do {
            try await repo.updateLog(
                uid: uid,
                createdAt: log.createdAt,
                newMood: editingMood,
                newNote: editingNote
            )

            // Reload month to reflect changes
            await load(uid: uid)

            // Keep the selected day as-is
            editingLog = nil
        } catch {
            print("MoodCalendarViewModel.saveEdit error: \(error.localizedDescription)")
        }
    }
}
