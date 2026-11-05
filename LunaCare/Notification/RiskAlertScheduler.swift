//
//  RiskAlertScheduler.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-26.
//

import Foundation
import UserNotifications

/// Applies trend-based red-flag rules to weekly insights.
final class RiskAlertScheduler {

    static let shared = RiskAlertScheduler()
    private init() {}

    private let lastAlertKey = "FA3_lastRiskAlertDate"
    private let requestID = "trend-red-flag"

    /// Sends at most one red-flag notification per calendar day, and only when trend alerts are enabled.
    func scheduleIfNeeded(from insights: [WeeklyInsight]) {
        guard NotificationPreferences.trendAlertsEnabled,
              let redFlag = insights.first(where: Self.isRedFlag) else { return }

        let previous = StorageScope.object(forKey: lastAlertKey) as? Date
        if let previous, Calendar.current.isDateInToday(previous) { return }
        StorageScope.set(Date(), forKey: lastAlertKey)

        let content = UNMutableNotificationContent()
        content.title = "Health Alert"
        content.body  = makeBody(from: redFlag)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)

        let key = lastAlertKey
        UNUserNotificationCenter.current().add(request) { error in
            guard let error else { return }
            print("Failed to schedule health alert:", error)
            DispatchQueue.main.async {
                StorageScope.set(previous, forKey: key)
            }
        }
    }

    // MARK: - Trend red-flag rules

    static func redFlagInsights(from insights: [WeeklyInsight]) -> [WeeklyInsight] {
        insights.filter(isRedFlag)
    }

    private static func isRedFlag(_ insight: WeeklyInsight) -> Bool {
        let name = insight.metric.lowercased()

        func exceeds(_ threshold: Double) -> Bool {
            guard let pct = insight.percentChange else { return true }
            return abs(pct) >= threshold
        }

        if name.contains("resting heart") {
            return insight.direction == "higher" && exceeds(5)
        }
        if name.contains("sleep efficiency") {
            return insight.direction == "lower" && exceeds(5)
        }
        if name.contains("sleep trouble") {
            return insight.direction == "higher" && exceeds(10)
        }
        if name.contains("wake after sleep onset") {
            return insight.direction == "higher" && exceeds(10)
        }
        return false
    }

    private func makeBody(from insight: WeeklyInsight) -> String {
        let change = insight.percentChange.map { " (\(String(format: "%+.1f%%", $0)))" } ?? ""
        return "Your \(insight.metric) is \(insight.direction.lowercased()) than last week\(change). Open LunaCare to see what this means."
    }
}
