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
    case symptoms    = "Symptoms"
    case body        = "Body Measurements"

    var description: String {
        switch self {
        case .heart:   return "How well your body is recovering and balancing stress."
        case .sleep:   return "Your rest, continuity, and nightly restoration."
        case .mood:    return "Emotional regulation and stress patterns across the week."
        case .activity:return "Activity balance supporting circulation and metabolism."
        case .symptoms:return "Changes in your manually recorded symptom check-ins."
        case .body:    return "Changes in body measurements recorded in Apple Health."
        }
    }

    var icon: String {
        switch self {
        case .heart: return "❤️"
        case .sleep: return "🌙"
        case .mood: return "🧠"
        case .activity: return "🚶‍♀️"
        case .symptoms: return "📝"
        case .body: return "⚖️"
        }
    }

    var tint: Color {
        switch self {
        case .heart: return Color(red: 0.82, green: 0.35, blue: 0.48)
        case .sleep: return Color(red: 0.48, green: 0.40, blue: 0.78)
        case .mood: return Color(red: 0.80, green: 0.56, blue: 0.31)
        case .activity: return Color(red: 0.25, green: 0.61, blue: 0.48)
        case .symptoms: return Color(red: 0.78, green: 0.48, blue: 0.38)
        case .body: return Color(red: 0.34, green: 0.53, blue: 0.68)
        }
    }

    func matches(_ metric: String) -> Bool {
        let lower = metric.lowercased()

        switch self {
        case .heart:
            return [
                "resting heart rate", "average heart rate", "walking heart rate",
                "heart rate variability", "respiratory rate", "blood oxygen", "vo2 max"
            ].contains(lower)
        case .sleep:
            return [
                "sleep hours", "deep sleep hours", "rem sleep hours", "core sleep hours",
                "sleep efficiency", "wake after sleep onset"
            ].contains(lower)
        case .mood:
            return lower == "mood score"
        case .activity:
            return [
                "steps", "walking distance", "flights climbed", "active energy",
                "basal energy", "exercise minutes", "stand hours"
            ].contains(lower)
        case .symptoms:
            return [
                "fatigue", "bleeding", "hair loss", "appetite issues", "sleep trouble"
            ].contains(lower)
        case .body:
            return lower == "weight"
        }
    }
}

// MARK: - View

struct InsightsOverviewView: View {
    @EnvironmentObject var vm: InsightsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                if vm.isLoading {
                    ProgressView("Analyzing your data…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)

                } else if vm.insights.isEmpty && !vm.hasAlerts && !vm.hasRiskScore {
                    emptyState

                } else {
                    if !vm.insights.isEmpty {
                        summaryCard
                    }

                    if vm.hasAlerts {
                        NavigationLink {
                            HealthAlertsView()
                                .environmentObject(vm)
                        } label: {
                            OverviewAlertCard(
                                alertCount: vm.alertCount,
                                metricNames: vm.alertMetricNames
                            )
                        }
                    }

                    if !vm.hasAlerts, let score = vm.ppdRiskScore {
                        NavigationLink {
                            HealthAlertsView()
                                .environmentObject(vm)
                        } label: {
                            InsightRiskScoreCard(
                                score: score,
                                threshold: Double(vm.highPPDScoreThresholdPercent) / 100
                            )
                        }
                        .buttonStyle(.plain)
                    }

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

                    if !vm.insights.isEmpty {
                        actions
                    }
                }

                if !vm.isLoading, let message = vm.riskAssessmentMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.lcLavenderSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .task { await vm.loadInsights(includeRiskAssessment: true) }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Insights")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Your health patterns, week by week.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "waveform.path.ecg")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.lcLavender)
                    .frame(width: 48, height: 48)
                    .background(Color.lcLavenderSoft, in: RoundedRectangle(cornerRadius: 16))
            }

            HStack(spacing: 8) {
                Label("Apple Health", systemImage: "applewatch")
                Label("Mood & symptoms", systemImage: "heart.text.square")
            }
            .font(.caption.weight(.medium))
            .foregroundColor(.secondary)

            if vm.isGuestMode {
                Label("Local data only", systemImage: "internaldrive")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private var summaryCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(
                        colors: [Color.lcLavender, Color.purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 15)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("\(vm.insights.count) trends ready")
                    .font(.headline)
                Text("Compared with the previous week")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.lcLavender.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .lcCardShadow, radius: 12, y: 5)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(Color.lcLavender)
                .frame(width: 68, height: 68)
                .background(Color.lcLavenderSoft, in: Circle())

            VStack(spacing: 7) {
                Text("Your trends are taking shape")
                    .font(.headline)
                Text("Insights appear when a metric has data on at least 5 days in each of the last two complete weeks.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label("Sync Apple Health or keep logging check-ins", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 30)
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.lcLavender.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6]))
        }
        .padding(.top, 8)
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
            HStack(spacing: 12) {
                Text(category.icon)
                    .font(.title3)
                    .frame(width: 42, height: 42)
                    .background(category.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.rawValue)
                        .font(.headline)
                    Text(category.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Text("\(insights.count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(category.tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(category.tint.opacity(0.12), in: Capsule())
            }

            ForEach(insights) { insight in
                NavigationLink {
                    InsightsDetailView(
                        category: category,
                        insights: insights
                    ).environmentObject(vm)
                } label: {
                    InsightCard(insight: insight, tint: category.tint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .lcCardShadow.opacity(0.6), radius: 10, y: 4)
        )
    }
}

// MARK: - Sparkline Card

private struct InsightCard: View {
    let insight: WeeklyInsight
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(insight.metric.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer(minLength: 8)
                Label(insight.direction.capitalized, systemImage: directionSymbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.12), in: Capsule())
            }

            HStack(alignment: .center, spacing: 12) {
                weeklyValue(title: "Previous week", value: insight.prev7Avg)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
                weeklyValue(title: "Last week", value: insight.last7Avg)
                Spacer(minLength: 0)
                MiniChart(last: insight.last7Avg, prev: insight.prev7Avg, tint: tint)
                    .frame(width: 64)
            }

            Text(insight.text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator).opacity(0.18), lineWidth: 1)
        }
    }

    private var directionSymbol: String {
        switch insight.direction {
        case "higher": return "arrow.up.right"
        case "lower": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private func weeklyValue(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(String(format: "%.1f", value))
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Tiny Chart

private struct MiniChart: View {
    let last: Double
    let prev: Double
    let tint: Color

    var body: some View {
        Chart {
            LineMark(x: .value("Week", 0), y: .value("Average", prev))
                .foregroundStyle(tint)
                .symbol(.circle)
            LineMark(x: .value("Week", 1), y: .value("Average", last))
                .foregroundStyle(tint)
                .symbol(.circle)
        }
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: chartDomain)
        .frame(height: 38)
    }

    private var chartDomain: ClosedRange<Double> {
        let low = min(prev, last)
        let high = max(prev, last)
        let padding = max(max((high - low) * 0.3, abs(high) * 0.03), 0.1)
        return (low - padding)...(high + padding)
    }
}

// MARK: - Alert Callout

private struct OverviewAlertCard: View {
    let alertCount: Int
    let metricNames: [String]

    var subtitle: String {
        let names = metricNames.map { $0.capitalized }
        if names.count == 1 { return "\(names[0]) triggered an alert. Tap to review." }
        return "\(names[0]) and \(names[1]) triggered alerts. Tap to review."
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

private struct InsightRiskScoreCard: View {
    let score: Double
    let threshold: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("PPD model score", systemImage: "brain.head.profile")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                Spacer()
                Text("\(Int((score * 100).rounded()))%")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(score >= threshold ? .red : .primary)
            }

            ProgressView(value: score, total: 1)
                .tint(score >= threshold ? .red : .lcLavender)

            Text(score >= threshold
                 ? "High-score alert. Open to view details."
                 : "Below the \(Int((threshold * 100).rounded()))% alert cutoff. Open to view details.")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Raw model output—not verified confidence or a diagnosis.")
                .font(.caption2)
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
