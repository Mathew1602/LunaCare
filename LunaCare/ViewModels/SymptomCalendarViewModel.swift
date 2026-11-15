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
    @Published var selectedEntries: [SymptomLogSummary] = []
    @Published var loadingMonth = false
    @Published var loadingSelected = false

    @Published var entryToDelete: SymptomLogSummary? = nil
    @Published var showingDeleteConfirmation = false
    @Published var deletingEntryId: String? = nil

    private let cal = Calendar.current
    private let repo: SymptomCalendarRepository
    private let localStore = LocalSymptomCalendarStore.shared
    private let syncManager = SyncManager.shared
    private var monthToken = UUID()
    private var dayToken = UUID()

    init(repo: SymptomCalendarRepository = SymptomCalendarRepository()) {
        self.repo = repo
    }

    // MARK: - Computed

    var monthStart: Date {
        let base = cal.date(byAdding: .month, value: monthOffset, to: Date())!
        return cal.date(from: cal.dateComponents([.year, .month], from: base))!
    }

    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: monthStart)
    }

    var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = .current
        return formatter.shortWeekdaySymbols
    }

    var daysGrid: [Date?] {
        let firstWeekday = cal.component(.weekday, from: monthStart)
        let leading = (firstWeekday + 6) % 7
        let days = cal.range(of: .day, in: .month, for: monthStart)!.count
        var array = Array<Date?>(repeating: nil, count: leading)
        for index in 0..<days {
            array.append(cal.date(byAdding: .day, value: index, to: monthStart)!)
        }
        return array
    }

    func hasSymptoms(on day: Date?) -> Bool {
        guard let day else { return false }
        return daysWithSymptoms.contains(cal.startOfDay(for: day))
    }

    func isToday(_ day: Date?) -> Bool {
        guard let day else { return false }
        return cal.isDateInToday(day)
    }

    var selectedTitle: String {
        guard let selected else { return "Select a day" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: selected)
    }

    private func usesLocal(_ uid: String) -> Bool {
        !syncManager.isCloudSyncOn || uid.isEmpty
    }

    // MARK: - Load Month

    func loadMonth(for uid: String) async {
        let token = UUID()
        monthToken = token
        loadingMonth = true
        defer { if token == monthToken { loadingMonth = false } }

        guard let days = await fetchMonthDays(uid: uid), token == monthToken else { return }
        daysWithSymptoms = days

        if selected == nil {
            if cal.isDate(Date(), equalTo: monthStart, toGranularity: .month) {
                selected = Date()
            } else {
                selected = daysWithSymptoms.sorted().first
            }
        }

        if let selected {
            await select(day: selected, uid: uid)
        }
    }

    private func fetchMonthDays(uid: String) async -> Set<Date>? {
        let month = monthStart
        if usesLocal(uid) {
            return localStore.fetchMonth(monthStart: month)
        }
        do {
            return try await repo.fetchMonth(uid: uid, monthStart: month)
        } catch {
            print("SymptomCalendarViewModel.loadMonth error: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Change Month

    func changeMonth(by delta: Int, uid: String) async {
        monthOffset += delta
        selected = nil
        selectedEntries = []
        await loadMonth(for: uid)
    }

    // MARK: - Select Day

    func select(day: Date, uid: String) async {
        let token = UUID()
        dayToken = token
        selected = day
        loadingSelected = true
        defer { if token == dayToken { loadingSelected = false } }

        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else {
            selectedEntries = []
            return
        }

        if usesLocal(uid) {
            selectedEntries = localStore.fetchRange(from: start, to: end)
                .sorted { $0.createdAt > $1.createdAt }
        } else {
            do {
                let logs = try await repo.fetchRange(uid: uid, from: start, to: end)
                guard token == dayToken else { return }
                selectedEntries = logs.sorted { $0.createdAt > $1.createdAt }
            } catch {
                guard token == dayToken else { return }
                print("SymptomCalendarViewModel.select error: \(error.localizedDescription)")
                selectedEntries = []
            }
        }
    }

    // MARK: - Delete

    func requestDelete(_ entry: SymptomLogSummary) {
        entryToDelete = entry
        showingDeleteConfirmation = true
    }

    func deleteSelectedEntry(uid: String) async {
        guard let entry = entryToDelete else { return }
        deletingEntryId = entry.id
        defer {
            deletingEntryId = nil
            entryToDelete = nil
        }

        if usesLocal(uid) {
            LocalSymptomStore.shared.deleteOfflineSymptomLog(createdAt: entry.createdAt)
        } else {
            do {
                try await repo.deleteLog(uid: uid, logId: entry.id)
            } catch {
                print("Unable to delete symptom log: \(error.localizedDescription)")
                return
            }
        }

        if let days = await fetchMonthDays(uid: uid) {
            daysWithSymptoms = days
        }
        if let selected {
            await select(day: selected, uid: uid)
        }
    }
}
