//
//  InsightsDetailView.swift
//  LunaCare
//
//  Restored & updated by Fernanda Battig on 2025-11-07
//


import SwiftUI
import Charts

struct InsightsDetailView: View {
    @EnvironmentObject var vm: InsightsViewModel

    let category: InsightCategory
    let insights: [WeeklyInsight]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                headerSection

                VStack(alignment: .leading, spacing: 18) {
                    Text("Week-to-week trends")
                        .font(.headline)

                    ForEach(insights) { item in
                        InsightBreakdownCard(insight: item)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationTitle("Insight Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(category.icon) \(category.rawValue)")
                .font(.system(.title, design: .rounded).bold())

            Text(category.description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}


// MARK: - Insight Breakdown Card

private struct InsightBreakdownCard: View {
    @EnvironmentObject var vm: InsightsViewModel

    let insight: WeeklyInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text(insight.metric.capitalized)
                    .font(.headline)

                Spacer()

                Label(insight.direction.capitalized, systemImage: directionSymbol)
                    .font(.subheadline.bold())
                    .foregroundColor(directionColor)
            }

            MetricWeeklyChart(insight: insight)
                .frame(height: 150)

            HStack {
                Text("Previous: \(String(format: "%.2f", insight.prev7Avg))")
                Spacer()
                Text("Last: \(String(format: "%.2f", insight.last7Avg))")
            }
            .font(.caption.monospacedDigit())
            .foregroundColor(.secondary)

            Text(insight.text)
                .font(.footnote)
                .foregroundColor(.secondary)

            if let coverage = vm.coverage(for: insight.metric) {
                Label(
                    "\(coverage.previousWeekDays)/7 days previous · \(coverage.lastWeekDays)/7 days last",
                    systemImage: coverage.isSufficient ? "checkmark.circle" : "exclamationmark.circle"
                )
                .font(.caption2)
                .foregroundColor(coverage.isSufficient ? .green : .secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.75))
        )
    }

    private var directionSymbol: String {
        switch insight.direction {
        case "higher": return "arrow.up.right"
        case "lower": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private var directionColor: Color {
        guard let metric = InsightMetric.allCases.first(where: {
            $0.label.caseInsensitiveCompare(insight.metric) == .orderedSame
        }), let higherIsBetter = metric.higherIsBetter else {
            return .secondary
        }

        if insight.direction == "about the same" {
            return .secondary
        }
        let isImprovement = (insight.direction == "higher" && higherIsBetter) ||
            (insight.direction == "lower" && !higherIsBetter)
        return isImprovement ? .green : .orange
    }
}

private struct MetricWeeklyChart: View {
    let insight: WeeklyInsight

    var body: some View {
        Chart {
            LineMark(
                x: .value("Week", "Previous"),
                y: .value("Average", insight.prev7Avg)
            )
            .foregroundStyle(.purple)
            .symbol(.circle)
            LineMark(
                x: .value("Week", "Last"),
                y: .value("Average", insight.last7Avg)
            )
            .foregroundStyle(.purple)
            .symbol(.circle)
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: ["Previous", "Last"]) { value in
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartYScale(domain: chartDomain)
    }

    private var chartDomain: ClosedRange<Double> {
        let low = min(insight.prev7Avg, insight.last7Avg)
        let high = max(insight.prev7Avg, insight.last7Avg)
        let padding = max((high - low) * 0.25, abs(high) * 0.03, 0.1)
        return (low - padding)...(high + padding)
    }
}
