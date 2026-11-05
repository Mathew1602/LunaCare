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
            HomeContentView(auth: auth, env: env)
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }

            SettingsView()
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
    @StateObject private var insightsVM: InsightsViewModel
    @Environment(\.scenePhase) private var scenePhase
    private var isSyncedToCloud: Bool { !auth.uid.isEmpty && env.isCloudSyncOn }
    @StateObject private var metricsStore = HomeMetricsStore.shared
    @State private var showEditMetrics = false
    @State private var storedMeasurements: [Measurement] = []

    @State private var showingMLTestAlert = false
    @State private var mlTestMessage = ""
    @State private var isRunningMLTest = false

    private let repo = MeasurementRepository()

    init(auth: AuthViewModel, env: AppEnvironment) {
        _insightsVM = StateObject(wrappedValue: InsightsViewModel(auth: auth, env: env))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hi \(auth.displayName.isEmpty ? "there" : auth.displayName),")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("how are you feeling today?")
                            .foregroundColor(.gray)

                        HStack {
                            Image(systemName: isSyncedToCloud ? "icloud" : "internaldrive")
                                .imageScale(.small)
                            Text(isSyncedToCloud ? "Synced to Cloud" : "Local Only")
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }

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

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Key Health Metrics")
                            .font(.headline)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3), spacing: 20) {
                            ForEach(metricsStore.selected) { metric in
                                MetricCard(icon: metric.icon,
                                           value: displayValue(for: metric),
                                           label: metric.title)
                            }
                        }
                    }
                    .padding(.top, 10)

                    if !insightsVM.isLoading && insightsVM.alertCount > 0 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Alerts")
                                .font(.headline)
                            NavigationLink {
                                HealthAlertsView()
                                    .environmentObject(insightsVM)
                            } label: {
                                HStack {
                                    Image(systemName: "bell.badge")
                                        .foregroundColor(Color(.systemIndigo))
                                    Text(alertSummary)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Text("View")
                                        .foregroundColor(Color(.systemIndigo))
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick Access")
                            .font(.headline)

                        HStack(spacing: 20) {
                            NavigationLink {
                                ReportsView()
                            } label: {
                                QuickAccessButton(icon: "doc.text.magnifyingglass", title: "Reports")
                            }
                            .buttonStyle(.plain)

                            Button {
                                runMLTest()
                            } label: {
                                QuickAccessButton(icon: "brain", title: "Prediction")
                            }
                            .buttonStyle(.plain)
                            .disabled(isRunningMLTest)
                            .alert("PPD Risk Prediction", isPresented: $showingMLTestAlert) {
                                Button("OK", role: .cancel) { }
                            } message: {
                                Text(mlTestMessage)
                            }

                            NavigationLink {
                                InsightsOverviewView()
                                    .environmentObject(insightsVM)
                            } label: {
                                QuickAccessButton(icon: "chart.bar.xaxis", title: "Insights")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 10)

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
                        Button {
                            showEditMetrics = true
                        } label: {
                            Label("Edit Health Metrics", systemImage: "slider.horizontal.3")
                        }

                        if !auth.email.isEmpty {
                            Text("Signed in as \(auth.email)")
                        }

                        Button("Sign out", role: .destructive) {
                            auth.signOut()
                        }
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
                    health.latestMeasurement = Measurement(steps: 8432,
                                                           activeEnergyKcal: 3231,
                                                           restingHRBpm: 71,
                                                           hrvSDNNms: 48,
                                                           sleepHours: 7.2,
                                                           deepSleepHours: 1.3)
                    return
                }
                #endif
                Task { await refreshHealth() }
            }
            .sheet(isPresented: $showEditMetrics) {
                EditHealthMetricsView(store: metricsStore, uid: auth.uid)
            }
            .task(id: auth.uid) {
                metricsStore.load(uid: auth.uid)
                await loadStoredMeasurements()
                await insightsVM.loadIfNeeded()
            }
            .onChange(of: env.isCloudSyncOn) { _, on in
                Task { await loadStoredMeasurements() }
                if on {
                    metricsStore.load(uid: auth.uid)
                    Task { await HealthDataPersistence.shared.persist(health.dailyMeasurements, uid: auth.uid) }
                }
            }
            .onChange(of: env.isSyncing) { _, syncing in
                if !syncing {
                    Task { await loadStoredMeasurements() }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await refreshHealth()
                    }
                }
            }
        }
    }

    private func refreshHealth() async {
        await health.authorizeAndRefresh()
        await HealthDataPersistence.shared.persist(health.dailyMeasurements, uid: auth.uid)
        await loadStoredMeasurements()
    }

    private var alertSummary: String {
        let count = insightsVM.alertCount
        let names = insightsVM.alertMetricNames.joined(separator: ", ")
        let lead = count == 1 ? "1 health alert" : "\(count) health alerts"
        return names.isEmpty ? lead : "\(lead): \(names)"
    }

    // MARK: - Stored measurement fallback (when HealthKit has no value)

    private func displayValue(for metric: HealthMetric) -> String {
        if health.isAuthorized {
            let live = metric.formattedValue(from: health.latestMeasurement)
            if live != "--" { return live }
        }
        for record in storedMeasurements.reversed() {
            let stored = metric.formattedValue(from: record)
            if stored != "--" { return stored }
        }
        return "--"
    }

    private func loadStoredMeasurements() async {
        if isSyncedToCloud {
            storedMeasurements = (try? await repo.fetchLastDays(uid: auth.uid, lastDays: 14)) ?? []
        } else {
            let today = Date()
            let from = Calendar.current.date(byAdding: .day, value: -13, to: today) ?? today
            storedMeasurements = LocalMeasurementStore.shared.fetchRange(from: from, to: today)
        }
    }

    // MARK: - ML Test (last 30 days)

    private func runMLTest() {
        guard !isRunningMLTest else { return }
        isRunningMLTest = true
        Task {
            defer { isRunningMLTest = false }
            do {
                if !auth.uid.isEmpty,
                   try await !PrivacyRepository().fetchConsent(uid: auth.uid).riskInsights {
                    mlTestMessage = "Risk insights are turned off in Data Privacy."
                    showingMLTestAlert = true
                    return
                }

                let loader = PPDWindowLoader()
                guard try await loader.hasMonthOfHistory(uid: auth.uid, fromCloud: isSyncedToCloud) else {
                    mlTestMessage = PPDWindowLoader.notEnoughHistoryMessage
                    showingMLTestAlert = true
                    return
                }
                let records = try await loader.load(uid: auth.uid, fromCloud: isSyncedToCloud)

                if records.isEmpty {
                    mlTestMessage = "No measurements in the last 30 days. Log data or sync your watch first."
                } else if let runner = PPDRiskModelRunner.shared {
                    let score = try runner.predictRisk(from: records)
                    let pct = PPDRiskTier.percent(score)
                    mlTestMessage = """
                    Last 30 days (\(records.count) days of data)
                    score = \(score, default: "%.3f")
                    (~\(pct)% risk) · \(PPDRiskTier(score: score).title)
                    """
                } else {
                    mlTestMessage = "Model unavailable"
                }
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
