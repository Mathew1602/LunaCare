
//
//  InsightsDetailView.swift
//
//
//  Restored by Fernanda Battig on 2025-11-07
//



import SwiftUI

// MARK: - Palette
private extension Color {
    static let lcLavender      = Color(red: 0.74, green: 0.68, blue: 0.95)
    static let lcLavenderSoft  = Color(red: 0.95, green: 0.95, blue: 0.98)
    static let lcCardShadow    = Color.black.opacity(0.08)
}

// MARK: - Screen
struct InsightsDetailView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Header
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.primary)
                        Text("Insights Details Overview")
                            .font(.system(.title, design: .rounded).bold())
                    }
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 6)

                    Text("How Sleep Affects Mood across the last 14 days.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

                // Mood–Sleep Correlation Card + mini chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mood–Sleep Correlation")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))

                    Text("Consistent bedtime enhances emotional stability.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.lcLavenderSoft)
                        .overlay(
                            LineChart(points: Demo.points)
                                .padding(16)
                        )
                        .frame(height: 220)
                        .shadow(color: .lcCardShadow, radius: 10, y: 6)

                    // Buttons under the chart
                    VStack(spacing: 12) {
                        // ✅ Use a label-only view in a NavigationLink
                        NavigationLink {
                            RecommendationsView()
                        } label: {
                            FilledButtonLabel(title: "View Recommendations")
                        }
                        .buttonStyle(.plain)

                        // This one can stay a real button since it doesn't navigate
                        Button {
                            // share action placeholder
                        } label: {
                            OutlineButtonLabel(title: "Share with Caregiver")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }

                // Additional highlight cards
                VStack(spacing: 16) {
                    InsightCardDetail(
                        title: "Sleep Window",
                        subtitle: "Best window: 10:15–11:00 PM. Falling asleep there correlated with higher mood the next day."
                    )
                    InsightCardDetail(
                        title: "Afternoon Activity",
                        subtitle: "10–20 min light walk after lunch correlates with improved afternoon energy."
                    )
                }

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

// MARK: - Components

private struct InsightCardDetail: View {
    let title: String
    let subtitle: String

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.lcLavenderSoft)
            .shadow(color: .lcCardShadow, radius: 10, y: 6)
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            )
            .frame(maxWidth: .infinity, minHeight: 96)
    }
}

private struct LineChart: View {
    let points: [CGPoint]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxX = max(points.map { $0.x }.max() ?? 1, 1)
            let maxY: CGFloat = max(points.map { $0.y }.max() ?? 1, 1)

            ZStack {
                // grid
                Path { p in
                    for y in stride(from: 0, through: maxY, by: max(1, maxY/5)) {
                        let yy = h - (y/maxY) * h
                        p.move(to: CGPoint(x: 0, y: yy))
                        p.addLine(to: CGPoint(x: w, y: yy))
                    }
                }
                .stroke(Color.black.opacity(0.06), lineWidth: 1)

                // line
                Path { p in
                    for (i, pt) in points.enumerated() {
                        let x = (pt.x / maxX) * w
                        let y = h - (pt.y / maxY) * h
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.lcLavender, lineWidth: 3)

                // dots
                ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                    let x = (pt.x / maxX) * w
                    let y = h - (pt.y / maxY) * h
                    Circle().fill(Color.lcLavender)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

// MARK: - Button Labels (no nested Button)
private struct FilledButtonLabel: View {
    var title: String
    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.lcLavender)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.lcCardShadow, radius: 12, y: 6)
    }
}

private struct OutlineButtonLabel: View {
    var title: String
    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.lcLavender)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
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

// MARK: - Demo data
private enum Demo {
    static let points: [CGPoint] = [
        .init(x: 0,  y: 4), .init(x: 1,  y: 6), .init(x: 2,  y: 3),
        .init(x: 3,  y: 5), .init(x: 4,  y: 4), .init(x: 5,  y: 7),
        .init(x: 6,  y: 6), .init(x: 7,  y: 5), .init(x: 8,  y: 4),
        .init(x: 9,  y: 6), .init(x: 10, y: 7), .init(x: 11, y: 5),
        .init(x: 12, y: 6), .init(x: 13, y: 8)
    ]
}

// MARK: - Preview
#Preview {
    NavigationStack { InsightsDetailView() }
}
