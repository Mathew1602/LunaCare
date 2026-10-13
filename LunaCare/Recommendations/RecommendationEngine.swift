//
//  RecommendationEngine.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-29.
//


import Foundation

enum RecommendationEngine {

    struct RecommendationItem: Identifiable, Codable {
        var id: String? // Firestore doc ID
        let title: String
        let subtitle: String
        let reason: String
        var timestamp: Date = Date()
    }


    static func build(from insights: [WeeklyInsight]) -> [RecommendationItem] {
        var items: [RecommendationItem] = []

        func metric(_ name: String) -> WeeklyInsight? {
            insights.first { $0.metric.lowercased() == name.lowercased() }
        }

        let sleepHours      = metric("sleep hours")
        let sleepEfficiency = metric("sleep efficiency")
        let sleepTrouble    = metric("sleep trouble")
        let wakeAfter       = metric("wake after sleep onset")
        let restingHR       = metric("resting heart rate")
        let mood            = metric("mood score")

        // Sleep Routine
        if let s = sleepHours {
            let pct = pctStr(s.percentChange)
            let sub = "Protect 10–11 PM bedtime, aim 7–8 hrs"

            let reason =
            s.direction == "higher" ?
            "You slept more vs last week (\(pct)). Keep consistency to maintain progress." :
            s.direction == "lower" ?
            "Sleep dropped (\(pct)). Limit screens before bed and unwind earlier." :
            "Sleep hours are stable. Consistency helps hormone + recovery balance."

            items.append(.init(title: "Sleep Routine",
                               subtitle: sub,
                               reason: reason))
        }

        // Wind-down breathing
        if let t = sleepTrouble ?? wakeAfter {
            let pct = pctStr(t.percentChange)
            let sub = "5 min slow breathing before bed"

            let reason =
            t.direction == "higher" ?
            "Night wake-ups increased (\(pct)). Relaxation drills can calm nervous system." :
            "Your nights improved. Keep relaxation habits before bed."

            items.append(.init(title: "Wind-Down Breathing",
                               subtitle: sub,
                               reason: reason))
        }

        // Light Activity
        if let hr = restingHR {
            let pct = pctStr(hr.percentChange)
            let sub = "10–15 min easy walk after lunch"

            let reason =
            hr.direction == "lower" ?
            "Resting HR lower (\(pct)). Indicates better recovery. Light walks maintain progress." :
            "Resting HR up (\(pct)). Gentle walks reduce stress hormones."

            items.append(.init(title: "Relaxed Movement",
                               subtitle: sub,
                               reason: reason))
        }

        // Activity trends
        let activityInsight = [
            metric("steps"),
            metric("exercise minutes"),
            metric("walking distance")
        ].compactMap { $0 }.first(where: { $0.direction == "lower" })
            ?? [metric("steps"), metric("exercise minutes"), metric("walking distance")]
                .compactMap { $0 }.first

        if let activity = activityInsight {
            let reason =
            activity.direction == "lower" ?
            "Your recorded \(activity.metric) trend was lower than last week (\(pctStr(activity.percentChange))). Choose movement that feels manageable and keep your routine comfortable." :
            activity.direction == "higher" ?
            "Your recorded \(activity.metric) trend was higher than last week (\(pctStr(activity.percentChange))). Keep a comfortable, sustainable routine." :
            "Your recorded \(activity.metric) trend was about the same as last week. Keep a comfortable, sustainable routine."

            items.append(.init(title: "Daily Movement",
                               subtitle: "Build activity into your day at a comfortable pace",
                               reason: reason))
        }

        if let mood {
            let reason =
            mood.direction == "lower" ?
            "Your recorded mood scores were lower than last week (\(pctStr(mood.percentChange))). Consider noting what support feels helpful to you." :
            mood.direction == "higher" ?
            "Your recorded mood scores were higher than last week (\(pctStr(mood.percentChange))). Notice which routines feel supportive." :
            "Your recorded mood scores were about the same as last week. Continue the routines that feel supportive."

            items.append(.init(title: "Mood Check-In",
                               subtitle: "Make space for a brief daily reflection",
                               reason: reason))
        }

        let symptomMetrics = [
            "fatigue", "bleeding", "hair loss", "appetite issues", "sleep trouble"
        ]
        let changedSymptoms = insights.filter {
            symptomMetrics.contains($0.metric.lowercased()) && $0.direction == "higher"
        }
        if !changedSymptoms.isEmpty {
            let names = changedSymptoms.map { $0.metric }.joined(separator: ", ")
            items.append(.init(
                title: "Symptom Check-In",
                subtitle: "Keep logging symptoms to see how they change over time",
                reason: "Your \(names) ratings were higher than last week. Keep tracking how you feel, and consider discussing persistent or concerning changes with your care team."
            ))
        }

        // Hydration (always relevant)
        let hydrationReason: String
        if let eff = sleepEfficiency, eff.direction == "lower" {
            hydrationReason = "Hydration supports sleep quality + HRV."
        } else {
            hydrationReason = "Better hydration supports mood & recovery."
        }

        items.append(.init(title: "Hydration",
                           subtitle: "2.0–2.5 L water through the day",
                           reason: hydrationReason))

        return items
    }

    private static func pctStr(_ v: Double) -> String {
        String(format: "%.1f%%", v)
    }
}
