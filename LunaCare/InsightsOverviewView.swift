//
//  InsightsOverviewView.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-10-19.
//




import SwiftUI

// MARK: - Palette (scoped to this file only)
private extension Color {
    static let lcLavender      = Color(red: 0.74, green: 0.68, blue: 0.95)
    static let lcLavenderSoft  = Color(red: 0.96, green: 0.95, blue: 0.99)
    static let lcCardShadow    = Color.black.opacity(0.08)
}

struct InsightsOverviewView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var env: AppEnvironment

    @State private var insights: [WeeklyInsight] = []
    @State private var isLoading = true

    private let service = InsightService.shared

    // MARK: - Tag style + Card

    private enum TagStyle {
        case capsule(String)
        case text(String)
    }

    private struct InsightCard: View {
        let title: String
        let subtitle: String
        let topRightTag: TagStyle?
        let bottomRightTag: TagStyle?
        let trailingIcon: AnyView?

        var body: some View {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.lcLavenderSoft)
                    .shadow(color: .lcCardShadow, radius: 12, y: 6)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)

                        Spacer()

                        if case let .capsule(text) = topRightTag {
                            Text(text)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.lcLavender.opacity(0.4))
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Spacer()

                        if case let .text(text) = bottomRightTag {
                            Text(text)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }

                        if let trailingIcon {
                            trailingIcon
                        }
                    }
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                header

                // Health Alerts banner (if any “alert” insights)
                if !alertInsights.isEmpty {
                    NavigationLink {
                        HealthAlertsView()
                    } label: {
                        AlertCard(alertCount: alertInsights.count,
                                  metricNames: alertInsights.prefix(2).map { $0.metric })
                    }
                }

                if isLoading {
                    ProgressView("Loading insights…")
                        .padding(.top, 20)

                } else if insights.isEmpty {
                    Text("No insights available yet.")
                        .foregroundColor(.secondary)
                        .padding(.top, 20)

                } else {
                    ForEach(insights) { item in
                        InsightCard(
                            title: item.metric,
                            subtitle: item.text,
                            topRightTag: .capsule(item.direction.capitalized),
                            bottomRightTag: .text(String(format: "%.1f%%", item.percentChange)),
                            trailingIcon: AnyView(
                                Image(systemName: arrowName(for: item))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(trendColor(for: item))
                            )
                        )
                    }
                }

                actions
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !auth.uid.isEmpty else { return }

            service.load(uid: auth.uid, cloudSyncOn: env.isCloudSyncOn) { list in
                insights = list
                isLoading = false

                // Schedule notifications for alerts, if any
                NotificationManager.shared.scheduleHealthAlertsIfNeeded(from: alertInsights)
            }
        }
    }

    // MARK: - Derived data

    /// Very simple heuristic: any insight whose text mentions “decline”
    /// (or “higher risk” in the future) is treated as an alert.
    private var alertInsights: [WeeklyInsight] {
        insights.filter { insight in
            let t = insight.text.lowercased()
            return t.contains("decline")
        }
    }

    private func arrowName(for insight: WeeklyInsight) -> String {
        switch insight.direction.lowercased() {
        case "higher": return "arrow.up"
        case "lower":  return "arrow.down"
        default:       return "arrow.right"
        }
    }

    private func trendColor(for insight: WeeklyInsight) -> Color {
        let text = insight.text.lowercased()
        if text.contains("improvement") { return .green }
        if text.contains("decline")     { return .red }
        return .gray
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("Your Health Insights")
                .font(.system(.largeTitle, design: .rounded).bold())
                .multilineTextAlignment(.center)

            Text("Weekly AI-powered analysis of your sleep, heart rate, and recovery.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    // MARK: - Alerts card

    private struct AlertCard: View {
        let alertCount: Int
        let metricNames: [String]

        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.red)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Health Alerts")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    Text(alertSubtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemRed).opacity(0.08))
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
        }

        private var alertSubtitle: String {
            if metricNames.isEmpty { return "View detailed health alerts." }
            if metricNames.count == 1 {
                return "Changes detected in \(metricNames[0]). Tap to view alerts."
            }
            return "Changes detected in \(metricNames[0]) and \(metricNames[1]). Tap to view alerts."
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 16) {
            NavigationLink {
                InsightsDetailView()
            } label: {
                Text("View Detailed Report")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.lcLavender)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.lcCardShadow, radius: 12, y: 6)
            }

            NavigationLink {
                HealthAlertsView()
            } label: {
                Text("View Health Alerts")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.lcLavender)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.lcLavender, lineWidth: 2)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.clear)
                    )
                    .shadow(color: Color.lcCardShadow, radius: 10, y: 6)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InsightsOverviewView()
            .environmentObject(AuthViewModel())
            .environmentObject(AppEnvironment.shared)
    }
}
