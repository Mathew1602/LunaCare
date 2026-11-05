//
//  WatchComponents.swift
//  LunaCareWatchOS Watch App
//
//  Created by Mathew Boyd on 2026-11-05.
//

import SwiftUI

struct RiskRing: View {
    let score: Double?
    var lineWidth: CGFloat = 6

    private var tier: PPDRiskTier? { score.map(PPDRiskTier.init(score:)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(score ?? 0, 0), 1))
                .stroke(tier?.color ?? .gray, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: score)
            if let score {
                Text("\(PPDRiskTier.percent(score))%")
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.6)
            } else {
                Image(systemName: "brain")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct WatchNavRow: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.2), in: Circle())
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct WatchEmptyState: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

extension SymptomLevel {
    var tint: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    static func tint(forValue value: Int) -> Color {
        SymptomLevel(rawValue: value)?.tint ?? .gray
    }
}

extension WatchConnectivityManager {
    func requestRisk() {
        send(Date(), type: .getRiskRequest)
    }
}
