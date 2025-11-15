//
//  MoodCalendarViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-11.
//
//

import Foundation

@MainActor
final class MoodCalendarViewModel: ObservableObject {

    @Published var monthOffset: Int = 0
    @Published var selected: Date? = nil

    @Published var logsByDay: [Date: [CalendarDayLog]] = [:]
    @Published var loading: Bool = false
    @Published var errorText: String? = nil

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
}
