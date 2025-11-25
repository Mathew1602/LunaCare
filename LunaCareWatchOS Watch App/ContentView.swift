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
            let full = p?.fullName.trimmingCharacters(in: .whitespaces) ?? ""
            if !full.isEmpty { return full }
            if let email = p?.email, !email.isEmpty { return email }
            return "there"
        }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Text("Hi \(displayName), how are you feeling today?")
                                      .font(.headline)
                                      .multilineTextAlignment(.center)
                                      .padding(.horizontal)
                    
                    // Navigate to Mood Logging
                    NavigationLink(destination: MoodTracking()) {
                        HStack {
                            Text("Log Mood")
                            Spacer()
                            Image(systemName: "smiley")
                        }
                        .padding()
                        .cornerRadius(12)
                    }
                    
                    // Health metrics section
                    VStack(alignment: .leading, spacing: 8) {
                    Text("Health Metrics")
                        .font(.subheadline)
                        .opacity(0.8)

                    HStack(spacing: 1) {
                        MetricView(
                            icon: "moon.fill",
                            label: health.isAuthorized
                                ? String(format: "%.1f hrs", health.sleepHours)
                                : "--",
                            detail: "Sleep"
                        )

                        MetricView(
                            icon: "flame.fill",
                            label: health.isAuthorized
                                ? "\(Int(health.activeEnergyKcal)) cal"
                                : "--",
                            detail: "Activity"
                        )

                        MetricView(
                            icon: "heart.fill",
                            label: health.isAuthorized
                                ? "\(Int(health.restingHR)) bpm"
                                : "--",
                            detail: "Resting HR"
                        )
                    }
                }
                .padding(.top)

                    // Navigation to all other screens
                    VStack(spacing: 8) {
                        NavigationLink("Symptoms Tracking", destination: SymptomsTrackingView())
                            .buttonStyle(.bordered)
                        NavigationLink("Mood History", destination: MoodHistoryView())
                            .buttonStyle(.bordered)
                        NavigationLink("SymptomHistory", destination: SymptomHistoryView())
                            .buttonStyle(.bordered)
                    }
                    .padding(.top)
                }
                .padding()
            }
        }
    }
}

struct MetricView: View {
    var icon: String
    var label: String
    var detail: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
            Text(label)
                .font(.footnote)
            Text(detail)
                .font(.caption2)
                .opacity(0.6)
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppleWatchDataStore.shared)
}
