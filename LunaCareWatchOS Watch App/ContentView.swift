//
//  ContentView.swift
//  LunaCareWatchOS Watch App
//
//  Created by Mathew Boyd on 2025-10-23.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var wc = WatchConnectivityManager.shared
    @EnvironmentObject var health: AppleWatchDataStore

    private var displayName: String {
        let p = wc.lastProfile
        let first = p?.firstName?.trimmingCharacters(in: .whitespaces) ?? ""
        if !first.isEmpty { return first }
        let full = p?.fullName.trimmingCharacters(in: .whitespaces) ?? ""
        return full.isEmpty ? "there" : full
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hi \(displayName)")
                            .font(.headline)
                        Text("How are you feeling?")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink(destination: RiskDetailView()) {
                        RiskCard(risk: wc.lastRisk)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        MetricView(icon: "moon.fill", tint: .indigo,
                                   value: health.isAuthorized ? String(format: "%.1f", health.sleepHours) : "--",
                                   detail: "hrs sleep")
                        MetricView(icon: "flame.fill", tint: .orange,
                                   value: health.isAuthorized ? "\(Int(health.activeEnergyKcal))" : "--",
                                   detail: "kcal")
                        MetricView(icon: "heart.fill", tint: .red,
                                   value: health.isAuthorized ? "\(Int(health.restingHR))" : "--",
                                   detail: "bpm")
                    }

                    Text("Check in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    NavigationLink(destination: MoodTracking()) {
                        WatchNavRow(title: "Log Mood", icon: "face.smiling", tint: .indigo)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: SymptomsTrackingView()) {
                        WatchNavRow(title: "Log Symptoms", icon: "cross.case.fill", tint: .pink)
                    }
                    .buttonStyle(.plain)

                    Text("History")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    NavigationLink(destination: MoodHistoryView()) {
                        WatchNavRow(title: "Mood History", icon: "calendar", tint: .purple)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: SymptomHistoryView()) {
                        WatchNavRow(title: "Symptom History", icon: "list.bullet.clipboard", tint: .teal)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("LunaCare")
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                health.isAuthorized = true
                health.sleepHours = 7.2
                health.activeEnergyKcal = 3231
                health.restingHR = 71
                return
            }
            #endif
            wc.requestRisk()
            Task { await health.authorizeAndRefresh() }
        }
    }
}

struct RiskCard: View {
    let risk: WatchRiskSummary?

    private var tier: PPDRiskTier? { risk?.score.map(PPDRiskTier.init(score:)) }

    var body: some View {
        HStack(spacing: 10) {
            RiskRing(score: risk?.score)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("PPD Prediction")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let tier {
                    Text(tier.title)
                        .font(.headline)
                        .foregroundStyle(tier.color)
                } else {
                    Text(risk == nil ? "Tap to check" : "Not available")
                        .font(.footnote.weight(.semibold))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            LinearGradient(colors: [(tier?.color ?? .indigo).opacity(0.35), Color.white.opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

struct MetricView: View {
    var icon: String
    var tint: Color
    var value: String
    var detail: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppleWatchDataStore.shared)
}
