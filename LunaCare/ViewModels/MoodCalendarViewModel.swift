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

    // Editing state
    @Published var editingLog: CalendarDayLog? = nil
    @Published var editingMood: Mood = .okay
    @Published var editingNote: String = ""
    @Published var isSavingEdit: Bool = false

    private let cal = Calendar.current
    private let repo: MoodCalendarRepository
    private let localStore = LocalMoodCalendarStore.shared
    private var syncManager = SyncManager.shared

    init(repo: MoodCalendarRepository = MoodCalendarRepository()) {
        self.repo = repo
        self.syncManager = .shared
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
        await load(uid: uid)
    }

    // MARK: - Load

    func load(uid: String) async {
        loading = true
        errorText = nil
        
        if await (!syncManager.getCloudSyncPreference(uid: uid, env: AppEnvironment.shared)) {
            logsByDay = localStore.fetchMonth(monthStart: monthStart)
            print("MoodCalendarViewModel: loaded \(logsByDay.count) days from local store.")
        } else {
            do {
                let map = try await repo.fetchMonth(uid: uid, monthStart: monthStart)
                logsByDay = map
            } catch {
                errorText = "Failed to load: \(error.localizedDescription)"
                print("MoodCalendarViewModel.load error: \(error.localizedDescription)")
            }
        }

        loading = false

        if selected == nil {
            if cal.isDate(Date(), equalTo: monthStart, toGranularity: .month) {
                selected = Date()
            } else {
                selected = logsByDay.keys.sorted().first
            }
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

        if await (!syncManager.getCloudSyncPreference(uid: uid, env: AppEnvironment.shared)) {
            localStore.updateLog(
                logId: log.id,
                newMood: editingMood,
                newNote: editingNote
            )
            let updatedMoodLog = MoodLog(
                id: log.id,
                mood: mapMoodToScore(editingMood),
                notes: editingNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : editingNote.trimmingCharacters(in: .whitespacesAndNewlines),
                tags: ["manual"],
                source: "manual",
                createdAt: log.createdAt
            )
            LocalMoodStore.shared.saveOfflineMood(updatedMoodLog)
            print("Mood edit saved locally for log id: \(log.id)")
            await load(uid: uid)
            
        } else {
            do {
                try await repo.updateLog(
                    uid: uid,
                    logId: log.id,
                    newMood: editingMood,
                    newNote: editingNote
                )
                await load(uid: uid)
            } catch {
                print("MoodCalendarViewModel.saveEdit error: \(error.localizedDescription)")
            }
        }

        editingLog = nil
    }

    // MARK: - Private
    private func mapMoodToScore(_ m: Mood) -> Int {
        switch m {
        case .ecstatic: return 4
        case .happy:    return 2
        case .okay:     return 0
        case .sad:      return -1
        case .angry:    return -2
        }
    }
}
