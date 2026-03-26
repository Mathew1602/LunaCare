//
//  SymptomCalendarViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-09.
//  Updated by Mathew to show per-time symptom logs for a selected day and support local storage.
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
    private let localStore = LocalSymptomCalendarStore.shared
    private var syncManager = SyncManager.shared

    init(repo: SymptomCalendarRepository = SymptomCalendarRepository()) {
        self.repo = repo
        self.syncManager = .shared
    }

    // MARK: - Computed

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
        guard let s = selected else { return "Select a day" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: s)
    }

    // MARK: - Load

    func loadMonth(for uid: String) async {
        loadingMonth = true
        defer { loadingMonth = false }

        if await (!syncManager.getCloudSyncPreference(uid: uid, env: AppEnvironment.shared)){
            daysWithSymptoms = localStore.fetchMonth(monthStart: monthStart)
            print("SymptomCalendarViewModel: loaded \(daysWithSymptoms.count) days from local store.")
        } else {
            do {
                let days = try await repo.fetchMonth(uid: uid, monthStart: monthStart)
                daysWithSymptoms = days
            } catch {
                print("SymptomCalendarViewModel.loadMonth error: \(error.localizedDescription)")
            }
        }

        if selected == nil {
            if cal.isDate(Date(), equalTo: monthStart, toGranularity: .month) {
                selected = Date()
            } else if let anyDay = daysWithSymptoms.first {
                selected = anyDay
            }
        }

        if let sel = selected {
            await select(day: sel, uid: uid)
        }
    }

    func changeMonth(by delta: Int, uid: String) async {
        monthOffset += delta
        await loadMonth(for: uid)
    }

    // MARK: - Selection

    func select(day: Date, uid: String) async {
        selected = day
        loadingSelected = true
        defer { loadingSelected = false }

        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else {
            selectedEntries = []
            return
        }

        if await (!syncManager.getCloudSyncPreference(uid: uid, env: AppEnvironment.shared)){
            selectedEntries = localStore.fetchRange(from: start, to: end)
            print("SymptomCalendarViewModel: loaded \(selectedEntries.count) entries locally for \(day).")
        } else {
            do {
                let logs = try await repo.fetchRange(uid: uid, from: start, to: end)
                selectedEntries = logs.sorted { $0.createdAt > $1.createdAt }
            } catch {
                print("SymptomCalendarViewModel.select error: \(error.localizedDescription)")
                selectedEntries = []
            }
        }
    }
}
