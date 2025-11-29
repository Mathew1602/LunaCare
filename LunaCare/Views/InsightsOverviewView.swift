//
//  InsightsOverviewView.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-10-19.
//



import SwiftUI
import Charts

// MARK: - Palette
private extension Color {
    static let lcLavender      = Color(red: 0.74, green: 0.68, blue: 0.95)
    static let lcLavenderSoft  = Color(red: 0.96, green: 0.95, blue: 0.99)
    static let lcCardShadow    = Color.black.opacity(0.08)
}

// MARK: - Categories

enum InsightCategory: String, CaseIterable, Hashable {
    case heart       = "Heart & Recovery"
    case sleep       = "Sleep Quality"
    case mood        = "Mood & Stress"
    case activity    = "Daily Movement"

    var description: String {
        switch self {
        case .heart:   return "How well your body is recovering and balancing stress."
        case .sleep:   return "Your rest, continuity, and nightly restoration."
        case .mood:    return "Emotional regulation and stress patterns across the week."
        case .activity:return "Activity balance supporting circulation and metabolism."
        }
    }

    var icon: String {
        switch self {
        case .heart: return "❤️"
        case .sleep: return "🌙"
        case .mood: return "🧠"
        case .activity: return "🚶‍♀️"
        }
    }

    func matches(_ metric: String) -> Bool {
        let lower = metric.lowercased()

        switch self {
        case .heart:
            return lower.contains("heart") || lower.contains("hrv")
        case .sleep:
            return lower.contains("sleep")
        case .mood:
            return lower.contains("mood") || lower.contains("stress")
        case .activity:
            return lower.contains("step") || lower.contains("exercise") || lower.contains("energy")
        }
    }
}

// MARK: - View

struct InsightsOverviewView: View {
    @EnvironmentObject var vm: InsightsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header

                if vm.isLoading {
                    ProgressView("Analyzing your data…")
                        .padding(.top, 20)

                } else if vm.insights.isEmpty {
                    Text("No insights yet — enable Cloud Sync in Settings.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)

                } else {

                    if !vm.alertInsights.isEmpty {
                        NavigationLink {
                            HealthAlertsView()
                                .environmentObject(vm)
                        } label: {
                            OverviewAlertCard(
                                alertCount: vm.alertInsights.count,
                                metricNames: vm.alertInsights.prefix(2).map { $0.metric }
                            )
                        }
                    }

                    // GROUPED BY CATEGORY 🔥
                    ForEach(InsightCategory.allCases, id: \.self) { category in
                        let filtered = vm.insights.filter { category.matches($0.metric) }

                        if !filtered.isEmpty {
                            InsightCategorySection(
                                category: category,
                                insights: filtered
                            )
                            .environmentObject(vm)
                        }
                    }

                    actions
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .task { await vm.loadInsights() }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Your Weekly Insights")
                .font(.largeTitle.bold())
            Text("Based on recent Apple Health trends.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.top, 12)
    }

    private var actions: some View {
        NavigationLink {
            RecommendationsView()
                .environmentObject(vm)
        } label: {
            Text("View Recommendations")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.lcLavender)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .lcCardShadow, radius: 10, y: 6)
        }
    }
}

// MARK: - Category Section

private struct InsightCategorySection: View {
    @EnvironmentObject var vm: InsightsViewModel

    let category: InsightCategory
    let insights: [WeeklyInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("\(category.icon) \(category.rawValue)")
                .font(.headline)

            Text(category.description)
                .font(.footnote)
                .foregroundColor(.secondary)

            ForEach(insights) { insight in
                NavigationLink {
                    InsightsDetailView(
                        category: category,
                        insights: insights
                    ).environmentObject(vm)
                } label: {
                    InsightCard(insight: insight)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.lcLavenderSoft.opacity(0.6))
                .shadow(color: .lcCardShadow, radius: 8, y: 4)
        )
    }
}

// MARK: - Sparkline Card

private struct InsightCard: View {
    let insight: WeeklyInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text(insight.metric.capitalized)
                    .font(.subheadline.bold())
                Spacer()
                Text(String(format: "%.1f%%", insight.percentChange))
                    .font(.footnote.bold())
                    .foregroundColor(insight.percentChange >= 0 ? .green : .red)
            }

            MiniChart(last: insight.last7Avg, prev: insight.prev7Avg)

            Text(insight.text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.6))
        )
    }
}

// MARK: - Tiny Chart

private struct MiniChart: View {
    let last: Double
    let prev: Double

    var body: some View {
        Chart {
            LineMark(x: .value("Week", "Previous"), y: .value("Avg", prev))
            LineMark(x: .value("Week", "Last"), y: .value("Avg", last))
        }
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 60)
    }
}

// MARK: - Alert Callout

private struct OverviewAlertCard: View {
    let alertCount: Int
    let metricNames: [String]

    var subtitle: String {
        let names = metricNames.map { $0.capitalized }
        if names.count == 1 { return "Changes in \(names[0]). Tap to view." }
        return "Changes in \(names[0]) and \(names[1]). Tap to view."
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.title2)
                .foregroundColor(.white)
                .padding(10)
                .background(Color.red)
                .clipShape(Circle())

            VStack(alignment: .leading) {
                Text("Health Alerts")
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lcLavenderSoft)
                .shadow(color: .lcCardShadow, radius: 8, y: 4)
        )
    }
}
