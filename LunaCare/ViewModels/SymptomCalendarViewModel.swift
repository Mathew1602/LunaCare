//
//  SymptomCalendarViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-11-14.
//
//
import Foundation
import SwiftUI

@MainActor
final class SymptomCalendarViewModel: ObservableObject {

    @Published var monthOffset: Int = 0
    @Published var selected: Date? = nil
    @Published private(set) var daysWithSymptoms: Set<Date> = []
    @Published private(set) var isLoading: Bool = false

    // details for the bottom section
    @Published private(set) var selectedDetails: [String: Int] = [:]

    private let cal = Calendar.current
    private let repo = SymptomCalendarRepository()

    var monthStart: Date {
        let base = Date()
        let offsetDate = cal.date(byAdding: .month, value: monthOffset, to: base) ?? base
        return cal.date(from: cal.dateComponents([.year, .month], from: offsetDate)) ?? base
    }

    var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: monthStart)
    }

    var weekdaySymbols: [String] {
        let f = DateFormatter()
        f.locale = .current
        return f.shortWeekdaySymbols   // S M T W T F S
    }

    var daysGrid: [Date?] {
        let firstWeekday = cal.component(.weekday, from: monthStart) // 1..7
        let leading = (firstWeekday + 6) % 7                         // 0..6
        let days = cal.range(of: .day, in: .month, for: monthStart)!.count

        var arr = Array<Date?>(repeating: nil, count: leading)
        for i in 0..<days {
            arr.append(cal.date(byAdding: .day, value: i, to: monthStart)!)
        }
        return arr
    }

    var selectedTitle: String {
        guard let d = selected else { return "No date selected" }
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: d)
    }

    func loadMonth(for uid: String) async {
        guard !uid.isEmpty else {
            daysWithSymptoms = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let set = try await repo.fetchMonth(uid: uid, monthStart: monthStart)
            daysWithSymptoms = set
        } catch {
            print("SymptomCalendarViewModel.loadMonth error:", error)
            daysWithSymptoms = []
        }
    }

    func select(day: Date, uid: String) async {
        selected = day

        guard !uid.isEmpty else {
            selectedDetails = [:]
            return
        }

        do {
            let details = try await repo.fetchDayValues(uid: uid, day: day)
            selectedDetails = details
        } catch {
            print("SymptomCalendarViewModel.select error:", error)
            selectedDetails = [:]
        }
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
    
    func changeMonth(by delta: Int, uid: String) async {
        monthOffset += delta
        await loadMonth(for: uid)
    }

}
