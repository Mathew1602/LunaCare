//
//  SymptomCalendarViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-09.
//  Updated by Mathew to show per-time symptom logs for a selected day.
//

import Foundation

@MainActor
final class SymptomCalendarViewModel: ObservableObject {


    @Published var monthOffset: Int = 0
    @Published var selected: Date? = nil

    @Published var daysWithSymptoms: Set<Date> = []

    /// All logs for the currently selected day (each with its own time + rows)
    @Published var selectedEntries: [SymptomLogSummary] = []

    @Published var loadingMonth: Bool = false
    @Published var loadingSelected: Bool = false


    private let cal = Calendar.current
    private let repo: SymptomCalendarRepository

    init(repo: SymptomCalendarRepository = SymptomCalendarRepository()) {
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
        let leading = (firstWeekday + 6) % 7      // shift so week starts on current locale’s first weekday
        let days = cal.range(of: .day, in: .month, for: monthStart)!.count

        var arr = Array<Date?>(repeating: nil, count: leading)
        for i in 0..<days {
            arr.append(cal.date(byAdding: .day, value: i, to: monthStart)!)
        }
        return arr
    }


    func hasSymptoms(on day: Date?) -> Bool {
        guard let d = day else { return false }
        let key = cal.startOfDay(for: d)
        return daysWithSymptoms.contains(key)
    }

    func isToday(_ day: Date?) -> Bool {
        guard let d = day else { return false }
        return cal.isDateInToday(d)
    }

    var selectedTitle: String {
        guard let s = selected else {
            return "Select a day"
        }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: s)
    }


    func loadMonth(for uid: String) async {
        guard !uid.isEmpty else { return }

        loadingMonth = true
        defer { loadingMonth = false }

        do {
            let days = try await repo.fetchMonth(uid: uid, monthStart: monthStart)
            daysWithSymptoms = days

            // If nothing is selected yet, select today if it's in this month, otherwise first day with symptoms
            if selected == nil {
                if cal.isDate(Date(), equalTo: monthStart, toGranularity: .month) {
                    selected = Date()
                } else if let anyDay = days.first {
                    selected = anyDay
                }
            }

        } catch {
            print("SymptomCalendarViewModel.loadMonth error: \(error.localizedDescription)")
        }

        // Refresh details for selected day if any
        if let sel = selected {
            await select(day: sel, uid: uid)
        }
    }

    func changeMonth(by delta: Int, uid: String) async {
        monthOffset += delta
        await loadMonth(for: uid)
    }

    func select(day: Date, uid: String) async {
        guard !uid.isEmpty else { return }

        selected = day
        loadingSelected = true
        defer { loadingSelected = false }

        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else {
            selectedEntries = []
            return
        }

        do {
            let logs = try await repo.fetchRange(uid: uid, from: start, to: end)
            selectedEntries = logs.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("SymptomCalendarViewModel.select error: \(error.localizedDescription)")
            selectedEntries = []
        }
    }
}
