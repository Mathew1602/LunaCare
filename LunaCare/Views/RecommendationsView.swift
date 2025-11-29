
//
//  RecommendationsView.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var env: AppEnvironment

    @State private var insights: [WeeklyInsight] = []
    @State private var recs: [RecommendationItem] = []
    @State private var sendDailyReminders = true

    public struct RecommendationItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let reason: String
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                header

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(recs) { item in
                        RecommendationCard(item: item)
                    }
                }
                .padding(.horizontal, 4)

                remindersSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationTitle("Recommendations")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Use the same generated fake-weekly insights
            insights = LocalStorageInsights.shared.load()
            recs = buildRecommendations(from: insights)
        }
    }

  

    private var header: some View {
        VStack(spacing: 8) {
            Text("Personalized Recommendations")
                .font(.system(.title, design: .rounded).bold())
                .multilineTextAlignment(.center)

            Text("Tailored to improve sleep, mood, stress, and energy based on your weekly trends.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    // MARK: - Reminders section

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $sendDailyReminders) {
                Text("Send daily reminders")
                    .font(.system(size: 16, weight: .semibold))
            }

            Button {
            } label: {
                Text("Mark as done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(sendDailyReminders ? .white : Color(.systemIndigo))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(sendDailyReminders ? Color(.systemIndigo) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(.systemIndigo), lineWidth: sendDailyReminders ? 0 : 2)
                            )
                    )
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Recommendation logic

    private func buildRecommendations(from insights: [WeeklyInsight]) -> [RecommendationItem] {
        var items: [RecommendationItem] = []

        // Helper to find a metric
        func metric(_ name: String) -> WeeklyInsight? {
            insights.first { $0.metric.lowercased() == name.lowercased() }
        }

        let sleepHours       = metric("sleep hours")
        let sleepEfficiency  = metric("sleep efficiency")
        let wakeAfter        = metric("wake after sleep onset")
        let sleepTrouble     = metric("sleep trouble score")
        let restingHR        = metric("resting heart rate")

        // Sleep routine recommendation
        if let s = sleepHours {
            let dir = s.direction
            let pct = String(format: "%.1f%%", s.percentChange)

            let subtitle = "Maintain a 10–11 PM bedtime and aim for 7–8 hours of sleep."
            let reason: String

            if dir == "higher" {
                reason = "Your sleep hours are higher vs last week (\(pct)). Keep this window consistent to stabilize mood and recovery."
            } else if dir == "lower" {
                reason = "Your sleep hours dropped (\(pct) vs last week). Try protecting your bedtime window and avoid screens 30–45 minutes before bed."
            } else {
                reason = "Your sleep duration is stable week-to-week. A consistent sleep window helps keep hormones and energy regulated."
            }

            items.append(.init(title: "Sleep Routine",
                               subtitle: subtitle,
                               reason: reason))
        }

        // Breathing / wind-down recommendation (based on wake after sleep onset or sleep trouble)
        if let trouble = sleepTrouble ?? wakeAfter {
            let pct = String(format: "%.1f%%", trouble.percentChange)
            let subtitle = "Try a 5-minute breathing or body-scan before bed."

            let reason: String
            if trouble.direction == "higher" {
                reason = "Night-time restlessness increased (\(pct) vs last week). Calming breathing drills can reduce awakenings and help you fall asleep faster."
            } else {
                reason = "Night-time restlessness is trending down (\(pct)). Keep using short breathing or relaxation routines to support this progress."
            }

            items.append(.init(title: "Wind-Down Breathing",
                               subtitle: subtitle,
                               reason: reason))
        }

        // Walking / light activity (resting HR)
        if let r = restingHR {
            let pct = String(format: "%.1f%%", r.percentChange)
            let subtitle = "Add a 10–15 minute easy walk during the afternoon."

            let reason: String
            if r.direction == "lower" {
                reason = "Your resting heart rate is lower vs last week (\(pct)), suggesting better recovery. Light daily walks help maintain this trend without over-loading you."
            } else if r.direction == "higher" {
                reason = "Resting heart rate is a bit higher (\(pct)). Gentle walks and stress-management can help bring it back down over time."
            } else {
                reason = "Resting heart rate is stable week-to-week. Short walks keep circulation and energy up without stressing your system."
            }

            items.append(.init(title: "Walking",
                               subtitle: subtitle,
                               reason: reason))
        }

        // Hydration – always useful, but tweak copy if sleep efficiency dropped
        let hydrationSubtitle = "Increase fluids to ~2.0–2.5 L/day and keep a water bottle visible."

        let hydrationReason: String
        if let eff = sleepEfficiency, eff.direction == "lower" {
            let pct = String(format: "%.1f%%", eff.percentChange)
            hydrationReason = "Sleep efficiency dipped (\(pct)). Staying well-hydrated can improve heart rate variability and sleep quality across the week."
        } else {
            hydrationReason = "Consistent hydration supports energy, mood, and recovery. Sipping water regularly is easier than drinking large amounts at once."
        }

        items.append(.init(title: "Hydration",
                           subtitle: hydrationSubtitle,
                           reason: hydrationReason))

        return items
    }
}


private struct RecommendationCard: View {
    let item: RecommendationsView.RecommendationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Text(item.subtitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.vertical, 4)

            Text(item.reason)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
}


#Preview {
    NavigationStack {
        RecommendationsView()
            .environmentObject(AuthViewModel())
            .environmentObject(AppEnvironment.shared)
    }
}
