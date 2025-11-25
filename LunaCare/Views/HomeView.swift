//
//  HomeView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-08.
//  Updated by Mathew on 2025-10-09
//  Updated by Fernanda
//  Updated by Xiaoya, fixing navigation link for 'log mood' button
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var env: AppEnvironment


    var body: some View {
        TabView {
            HomeContentView()
                .environmentObject(env)
                .environmentObject(auth)
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }

            SettingsView()
                .environmentObject(auth)
                .environmentObject(env)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
        .tint(Color(.systemIndigo))
    }
}

struct HomeContentView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var health = AppleWatchDataStore.shared
    
    @State private var showingMLTestAlert = false
    @State private var mlTestMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hi \(auth.displayName.isEmpty ? "there" : auth.displayName),")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("how are you feeling today?")
                            .foregroundColor(.gray)

                        // Sync status chip
                        HStack {
                            Image(systemName: env.isCloudSyncOn ? "icloud" : "internaldrive")
                                .imageScale(.small)
                            Text(env.isCloudSyncOn ? "Synced to Cloud" : "Local Only")
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .accessibilityLabel(env.isCloudSyncOn ? "Cloud sync enabled" : "Cloud sync disabled")
                    }

               
                    // Log Mood Button
                    NavigationLink(destination: MoodTrackingView()) {
                        HStack {
                            Text("Log Mood")
                            Image(systemName: "smiley")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemIndigo).opacity(0.2))
                        .foregroundColor(Color(.systemIndigo))
                        .cornerRadius(10)
                    }
                    .padding(.top, 10)

                    // Key Health Metrics
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Key Health Metrics")
                            .font(.headline)

                        HStack(spacing: 20) {
                            MetricCard(icon: "moon",
                                       value: health.isAuthorized ? String(format: "%.1f hrs", health.sleepHours) : "--",
                                       label: "Sleep")

                            MetricCard(icon: "waveform.path.ecg",
                                       value: health.isAuthorized ? "\(Int(health.activeEnergyKcal)) cal" : "--",
                                       label: "Activity")

                            MetricCard(icon: "heart",
                                       value: health.isAuthorized ? "\(Int(health.restingHR)) bpm" : "--",
                                       label: "Resting HR")
                        }

                    }
                    .padding(.top, 10)

                    // Alerts
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Alerts")
                            .font(.headline)
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(Color(.systemIndigo))
                            Text("Your sleep has been low for 2 nights")
                            Spacer()
                            Text("View Tips")
                                .foregroundColor(Color(.systemIndigo))
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }

                    // Quick Access
                    HStack(spacing: 20) {
                        QuickAccessButton(icon: "doc.text.magnifyingglass", title: "Reports")
                        Button {
                               runFakeMLTest()
                           } label: {
                               QuickAccessButton(icon: "doc.text.magnifyingglass", title: "Test ML")
                           }
                           .buttonStyle(.plain)
                           .alert("PPD Risk Test", isPresented: $showingMLTestAlert) {
                               Button("OK", role: .cancel) { }
                           } message: {
                               Text(mlTestMessage)
                           }
                        NavigationLink {
                            InsightsOverviewView()
                        } label: {
                            QuickAccessButton(icon: "chart.bar.xaxis", title: "Insights")
                        }
                        
                    }

                    // Trackers + Calendars
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Trackers")
                            .font(.headline)
                            .padding(.top, 20)

                        NavigationLink {
                            MoodTrackingView().environmentObject(auth)
                        } label: {
                            HStack {
                                Label("Mood Tracking", systemImage: "face.smiling")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }

                        NavigationLink {
                            SymptomsTrackingView()
                        } label: {
                            HStack {
                                Label("Symptoms Tracking", systemImage: "cross.case")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }

                        Text("Calendar")
                            .font(.headline)
                            .padding(.top, 8)

                        NavigationLink {
                            MoodCalendarView()
                        } label: {
                            HStack {
                                Label("Mood Calendar", systemImage: "calendar")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }

                        NavigationLink {
                            SymptomCalendarView()
                        } label: {
                            HStack {
                                Label("Symptom Calendar", systemImage: "calendar")
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding()
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if !auth.email.isEmpty {
                            Text("Signed in as \(auth.email)")
                        }
                        Button("Sign out", role: .destructive) { auth.signOut() }
                    } label: {
                        Image(systemName: "gear")
                    }
                }
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
                Task { await health.authorizeAndRefresh() }
            }

        }
        
    }
    private func runFakeMLTest() {
        Task {
            do {
                let fake30 = FakeStruct.highRisk30Days()
                let score = try PPDRiskModelRunner.shared.predictRisk(from: fake30)

                let pct = Int((score * 100).rounded())
                mlTestMessage = """
                Fake 30-day high-risk data result:
                score = \(score, default: "%.3f")
                (~\(pct)% risk)
                """

            } catch {
                mlTestMessage = "Couldn’t run model: \(error.localizedDescription)"
            }

            showingMLTestAlert = true
        }
    }
}
    


#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
        .environmentObject(AppEnvironment.shared)
}
