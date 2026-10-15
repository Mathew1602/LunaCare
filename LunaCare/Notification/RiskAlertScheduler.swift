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

    /// Schedules one notification when a weekly insight matches a red-flag rule.
    /// It will:
    /// - Look for a red-flag metric
    /// - Send ONE notification if needed
    /// - Never send more than once per calendar day
    func scheduleIfNeeded(from insights: [WeeklyInsight]) {
        guard let redFlag = insights.first(where: Self.isRedFlag) else {
            return
        }

        // Check if we already notified today
        if let last = UserDefaults.standard.object(forKey: lastAlertKey) as? Date,
           Calendar.current.isDateInToday(last) {
            return   // already notified today -> do nothing
        }

        //  Schedule local notification
        let content = UNMutableNotificationContent()
        content.title = "Health Alert"
        content.body  = makeBody(from: redFlag)
        content.sound = .default

        // Small delay so it feels “later”, not exactly when you tap
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        let center = UNUserNotificationCenter.current()

       
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule health alert:", error)
            } else {
                UserDefaults.standard.set(Date(), forKey: self.lastAlertKey)
            }
        }
    }

    // MARK: - Trend red-flag rules

    static func redFlagInsights(from insights: [WeeklyInsight]) -> [WeeklyInsight] {
        insights.filter(isRedFlag)
    }

    private static func isRedFlag(_ insight: WeeklyInsight) -> Bool {
        let name = insight.metric.lowercased()
        let change = abs(insight.percentChange)

        // Resting HR higher by ≥ 5%
        if name.contains("resting heart") {
            return insight.direction == "higher" && change >= 5
        }

        // Sleep efficiency lower by ≥ 5%
        if name.contains("sleep efficiency") {
            return insight.direction == "lower" && change >= 5
        }

        // Sleep trouble score higher by ≥ 10%
        if name.contains("sleep trouble") {
            return insight.direction == "higher" && change >= 10
        }

        // Wake after sleep onset higher by ≥ 10%
        if name.contains("wake after sleep onset") {
            return insight.direction == "higher" && change >= 10
        }

        return false
    }

    private func makeBody(from insight: WeeklyInsight) -> String {
        // Short, user-friendly sentence
        return "\(insight.metric) is \(insight.direction.lowercased()) vs last week (\(String(format: "%.1f%%", insight.percentChange))). Open LunaCare to see what this means."
    }
}
