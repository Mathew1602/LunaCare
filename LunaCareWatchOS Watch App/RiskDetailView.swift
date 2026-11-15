//
//  RiskDetailView.swift
//  LunaCareWatchOS Watch App
//
//  Created by Mathew Boyd on 2026-11-05.
//

import SwiftUI
import Combine

struct RiskDetailView: View {
    @ObservedObject private var wc = WatchConnectivityManager.shared
    @State private var isRefreshing = false

    private var risk: WatchRiskSummary? { wc.lastRisk }
    private var tier: PPDRiskTier? { risk?.score.map(PPDRiskTier.init(score:)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                RiskRing(score: risk?.score, lineWidth: 9)
                    .frame(width: 84, height: 84)
                    .padding(.top, 4)

                if let tier {
                    Text(tier.title)
                        .font(.headline)
                        .foregroundStyle(tier.color)
                    Text(tier.summary)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                } else {
                    Text(risk?.message ?? "No prediction yet. Tap refresh with your iPhone nearby.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }

                if let risk {
                    Text("Updated \(risk.computedAt, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Button {
                    refresh()
                } label: {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRefreshing)

                VStack(spacing: 4) {
                    Text(PPDRiskTier.rangeDescription)
                    Text("Based on your last 30 days. Not a diagnosis.")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Prediction")
        .onReceive(wc.$lastReceived.compactMap { $0 }) { msg in
            if msg.type == .getRiskResponse { isRefreshing = false }
        }
    }

    private func refresh() {
        isRefreshing = true
        wc.requestRisk()
        Task {
            try? await Task.sleep(for: .seconds(15))
            isRefreshing = false
        }
    }
}

#Preview {
    NavigationStack { RiskDetailView() }
}
