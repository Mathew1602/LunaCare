//
//  MoodCalendarViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-11.
//  Updated by Mathew to support editing existing mood logs and local storage.
//

import Foundation
import FirebaseFirestore

@MainActor
final class MoodCalendarViewModel: ObservableObject {

    @Published var monthOffset: Int = 0
    @Published var selected: Date? = nil

    @Published var logsByDay: [Date: [CalendarDayLog]] = [:]
    @Published var loading: Bool = false
    @Published var errorText: String? = nil

    @Published var editingLog: CalendarDayLog? = nil
    @Published var editingMood: Mood = .okay
    @Published var editingNote: String = ""
    @Published var isSavingEdit: Bool = false

    @Published var logToDelete: CalendarDayLog? = nil
    @Published var showingDeleteConfirmation = false
    @Published var isDeleting = false

    private let cal = Calendar.current
    private let repo: MoodCalendarRepository
    private let localStore = LocalMoodCalendarStore.shared
    private let syncManager = SyncManager.shared
    private var loadToken = UUID()

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

    // MARK: - Navigation

    func setMonth(delta: Int, uid: String) async {
        monthOffset += delta
        selected = nil
        await load(uid: uid)
    }

    // MARK: - Load

    func load(uid: String) async {
        let token = UUID()
        loadToken = token
        let month = monthStart
        loading = true
        errorText = nil

        if !syncManager.isCloudSyncOn || uid.isEmpty {
            logsByDay = localStore.fetchMonth(monthStart: month)
        } else {
            var showedCache = false
            if let cached = try? await repo.fetchMonth(uid: uid, monthStart: month, source: .cache),
               token == loadToken, !cached.isEmpty {
                logsByDay = cached
                showedCache = true
                loading = false
                selectDefaultDayIfNeeded()
            }
            do {
                let map = try await repo.fetchMonth(uid: uid, monthStart: month)
                guard token == loadToken else { return }
                logsByDay = map
            } catch {
                guard token == loadToken else { return }
                if !showedCache { logsByDay = [:] }
                errorText = "Failed to load: \(error.localizedDescription)"
            }
        }

        loading = false
        selectDefaultDayIfNeeded()
    }

    private func selectDefaultDayIfNeeded() {
        guard selected == nil else { return }
        if cal.isDate(Date(), equalTo: monthStart, toGranularity: .month) {
            selected = Date()
        } else {
            selected = logsByDay.keys.sorted().first
        }
    }

    // MARK: - Helpers

    func latestMood(for day: Date?) -> Mood? {
        guard let day else { return nil }
        return logsByDay[cal.startOfDay(for: day)]?.first?.mood
    }

    func logsForSelected() -> [CalendarDayLog] {
        guard let s = selected else { return [] }
        return logsByDay[cal.startOfDay(for: s)] ?? []
    }

    // MARK: - Editing
    func beginEdit(log: CalendarDayLog) {
        editingLog = log
        editingMood = log.mood
        editingNote = log.note ?? ""
    }

    func saveEdit(uid: String) async {
        guard let log = editingLog else { return }
        isSavingEdit = true
        defer { isSavingEdit = false }
        errorText = nil

        let trimmedNote = editingNote.trimmingCharacters(in: .whitespacesAndNewlines)

        if !syncManager.isCloudSyncOn || uid.isEmpty {
            localStore.updateLog(logId: log.id, newMood: editingMood, newNote: trimmedNote)
            let original = LocalMoodStore.shared.loadOfflineMoods().first { $0.id == log.id }
            let updatedMoodLog = MoodLog(
                id: log.id,
                mood: editingMood.score,
                notes: trimmedNote.isEmpty ? nil : trimmedNote,
                tags: original?.tags ?? ["manual"],
                source: original?.source ?? "manual",
                createdAt: log.createdAt,
                updatedAt: Date()
            )
            LocalMoodStore.shared.saveOfflineMood(updatedMoodLog)
        } else {
            do {
                try await repo.updateLog(uid: uid, logId: log.id, newMood: editingMood, newNote: trimmedNote)
            } catch {
                errorText = "Couldn’t save your changes: \(error.localizedDescription)"
                return
            }
        }

        editingLog = nil
        await load(uid: uid)
    }

    // MARK: - Delete

    func requestDelete(log: CalendarDayLog) {
        logToDelete = log
        showingDeleteConfirmation = true
    }

    func deleteLog(uid: String) async {
        guard let log = logToDelete else { return }
        isDeleting = true
        errorText = nil
        defer {
            isDeleting = false
            logToDelete = nil
        }

        if !syncManager.isCloudSyncOn || uid.isEmpty {
            localStore.deleteLog(logId: log.id)
            LocalMoodStore.shared.deleteOfflineMood(id: log.id)
        } else {
            do {
                try await repo.deleteLog(uid: uid, logId: log.id)
            } catch {
                errorText = "Unable to delete mood entry: \(error.localizedDescription)"
                return
            }
        }

        await load(uid: uid)
    }
}
