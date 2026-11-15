//
//  NotificationPreferences.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-11-05.
//

import Foundation

enum NotificationPreferences {
    static let dailyReminderEnabledKey = "notif.dailyReminder.enabled"
    static let dailyReminderHourKey = "notif.dailyReminder.hour"
    static let dailyReminderMinuteKey = "notif.dailyReminder.minute"
    static let trendAlertsEnabledKey = "notif.trendAlerts.enabled"
    static let ppdAlertsEnabledKey = "notif.ppdAlerts.enabled"

    static let defaultReminderHour = 20
    static let defaultReminderMinute = 0

    private static var defaults: UserDefaults { .standard }

    static var dailyReminderEnabled: Bool {
        defaults.object(forKey: dailyReminderEnabledKey) as? Bool ?? false
    }

    static var dailyReminderHour: Int {
        defaults.object(forKey: dailyReminderHourKey) as? Int ?? defaultReminderHour
    }

    static var dailyReminderMinute: Int {
        defaults.object(forKey: dailyReminderMinuteKey) as? Int ?? defaultReminderMinute
    }

    static var trendAlertsEnabled: Bool {
        defaults.object(forKey: trendAlertsEnabledKey) as? Bool ?? true
    }

    static var ppdAlertsEnabled: Bool {
        defaults.object(forKey: ppdAlertsEnabledKey) as? Bool ?? true
    }
}
