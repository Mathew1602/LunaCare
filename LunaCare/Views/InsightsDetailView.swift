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

                CombinedCategoryChart(insights: insights)
                    .frame(height: 220)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 18) {
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
    let insight: WeeklyInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text(insight.metric.capitalized)
                    .font(.headline)

                Spacer()

                Text(String(format: "%.1f%%", insight.percentChange))
                    .font(.subheadline.bold())
                    .foregroundColor(insight.percentChange >= 0 ? .green : .red)
            }

            Text(insight.text)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.75))
        )
    }
}


// MARK: - Combined Multi-Metric Category Chart

private struct CombinedCategoryChart: View {
    let insights: [WeeklyInsight]

    var body: some View {
        Chart {
            ForEach(insights) { item in

                LineMark(
                    x: .value("Week", "Previous"),
                    y: .value("Avg", item.prev7Avg)
                )
                .foregroundStyle(color(for: item))
                .interpolationMethod(.catmullRom)
                .symbol(by: .value("Metric", item.metric))

                LineMark(
                    x: .value("Week", "Last"),
                    y: .value("Avg", item.last7Avg)
                )
                .foregroundStyle(color(for: item))
                .interpolationMethod(.catmullRom)
                .symbol(by: .value("Metric", item.metric))
            }
        }
        .chartLegend(.visible)
        .chartXAxis {
            AxisMarks(values: ["Previous", "Last"])
        }
        .chartYAxis {
            AxisMarks()
        }
    }

    // Pastel theme unique per metric
    private func color(for insight: WeeklyInsight) -> Color {
        let name = insight.metric.lowercased()
        if name.contains("rest") { return Color(red: 0.67, green: 0.63, blue: 0.94) } // lavender
        if name.contains("avg")  { return Color(red: 0.62, green: 0.80, blue: 0.87) } // aqua
        if name.contains("walk") { return Color(red: 0.76, green: 0.84, blue: 0.69) } // green pastel
        if name.contains("sleep") { return Color(red: 0.85, green: 0.74, blue: 0.92) } // violet softer
        return .purple.opacity(0.7)
    }
}
