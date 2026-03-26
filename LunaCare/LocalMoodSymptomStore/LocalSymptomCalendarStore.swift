//
//  LocalSymptomCalendarStore.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-15.
//

import Foundation

final class LocalSymptomCalendarStore {
    static let shared = LocalSymptomCalendarStore()
    private init() {}

    private let cal = Calendar.current

    // MARK: - Read
    func fetchMonth(monthStart: Date) -> Set<Date> {
        guard let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
        }

        let summaries = LocalSymptomStore.shared.offlineSymptomHistory(
            from: monthStart,
            to: monthEnd
        )

        let days = summaries.map { cal.startOfDay(for: $0.createdAt) }
        return Set(days)
    }

    func fetchRange(from: Date, to: Date) -> [SymptomLogSummary] {
        LocalSymptomStore.shared.offlineSymptomHistory(from: from, to: to)
    }
}
