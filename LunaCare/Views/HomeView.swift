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
    @State private var mlTestTitle = "Your Wellbeing Check"
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

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                            spacing: 12
                        ) {
                            ForEach(Array(metricsStore.selected.enumerated()), id: \.element.id) { index, metric in
                                ColorfulMetricCard(
                                    icon: metric.icon,
                                    value: displayValue(for: metric),
                                    label: metric.title,
                                    tint: HomePalette.tint(for: metric.title, index: index)
                                )
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
                                QuickActionTile(
                                    icon: "brain",
                                    title: "Prediction",
                                    tint: HomePalette.lilac
                                )
                            }
                            .alert(
                                mlTestTitle,
                                isPresented: $showingMLTestAlert
                            ) {
                                Button("OK", role: .cancel) { }
                            } message: {
                                Text(mlTestMessage)
                            }

                            NavigationLink {
                                InsightsOverviewView()
                                    .environmentObject(auth)
                                    .environmentObject(env)
                                    .environmentObject(InsightsViewModel(auth: auth, env: env))
                            } label: {
                                QuickActionTile(
                                    icon: "chart.bar.xaxis",
                                    title: "Insights",
                                    tint: HomePalette.mint
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 10)

                    // Trackers + Calendars
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Trackers")
                            .font(.headline)
                            .padding(.top, 10)

                        NavigationLink {
                            MoodTrackingView().environmentObject(auth)
                        } label: {
                            TrackerRow(icon: "face.smiling", title: "Mood Tracking")
                        }

                        NavigationLink {
                            SymptomsTrackingView()
                        } label: {
                            TrackerRow(icon: "cross.case", title: "Symptoms Tracking")
                        }

                        Text("Calendar")
                            .font(.headline)
                            .padding(.top, 8)

                        NavigationLink {
                            MoodCalendarView()
                        } label: {
                            TrackerRow(icon: "calendar", title: "Mood Calendar")
                        }

                        NavigationLink {
                            SymptomCalendarView()
                        } label: {
                            TrackerRow(icon: "calendar.badge.clock", title: "Symptom Calendar")
                        }
                    }
                    .buttonStyle(.plain)
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
            let result = await PPDRiskCheck.run(uid: auth.uid, fromCloud: isSyncedToCloud)

            if let score = result.score {
                let tier = PPDRiskTier(score: score)
                let advice = RiskLevel(score: score).advice
                let days = result.dataDays == 1 ? "1 day" : "\(result.dataDays) days"

                mlTestTitle = "Your Wellbeing Check"
                mlTestMessage = """
                Risk level: \(tier.title) (\(PPDRiskTier.percent(score))%)

                \(advice)

                Based on \(days) of your data. This is not a diagnosis.
                """
            } else {
                mlTestTitle = "Wellbeing Check"
                mlTestMessage = result.message ?? "The prediction isn't available right now. Please try again later."
            }

            showingMLTestAlert = true
        }
    }
// MARK: - Home palette

fileprivate enum HomePalette {

    /// Dark text used on top of pastel tiles (same in light and dark mode)
    static let ink = Color(red: 0.10, green: 0.10, blue: 0.12)

    static let lime  = Color(red: 0.84, green: 0.94, blue: 0.47)
    static let lilac = Color(red: 0.89, green: 0.78, blue: 0.97)
    static let peach = Color(red: 1.00, green: 0.84, blue: 0.72)
    static let mint  = Color(red: 0.76, green: 0.91, blue: 0.85)
    static let sky   = Color(red: 0.78, green: 0.86, blue: 0.98)
    static let coral = Color(red: 1.00, green: 0.72, blue: 0.68)

    // Surfaces — adapt to dark mode
    static let card = Color.homeDynamic(
        light: .white,
        dark:  Color(red: 0.13, green: 0.13, blue: 0.14)
    )
    static let text = Color.homeDynamic(
        light: Color(red: 0.10, green: 0.10, blue: 0.12),
        dark:  Color(red: 0.96, green: 0.96, blue: 0.94)
    )

    // Purple accents for tracker rows
    static let purple = Color.homeDynamic(
        light: Color(red: 0.43, green: 0.36, blue: 0.85),
        dark:  Color(red: 0.72, green: 0.66, blue: 1.00)
    )
    static let lavender = Color.homeDynamic(
        light: Color(red: 0.94, green: 0.92, blue: 0.99),
        dark:  Color(red: 0.23, green: 0.20, blue: 0.34)
    )
    static let lavenderBorder = Color.homeDynamic(
        light: Color(red: 0.89, green: 0.86, blue: 0.97),
        dark:  Color(red: 0.28, green: 0.25, blue: 0.40)
    )

    private static let fallback: [Color] = [mint, lime, peach, sky, lilac, coral]

    /// Fixed colour per metric type; anything unknown cycles through the palette.
    static func tint(for title: String, index: Int) -> Color {
        let t = title.lowercased()
        if t.contains("sleep") { return lilac }
        if t.contains("hrv") || t.contains("variability") { return sky }
        if t.contains("heart") || t.contains("hr") { return coral }
        if t.contains("energy") || t.contains("calor") { return peach }
        if t.contains("step") || t.contains("walk") { return lime }
        return fallback[index % fallback.count]
    }
}


// MARK: - Dynamic colour helper

fileprivate extension Color {
    static func homeDynamic(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}


// MARK: - Colourful metric card (filled = information)

struct ColorfulMetricCard: View {

    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HomePalette.ink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(.white.opacity(0.75)))

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(HomePalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(HomePalette.ink.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tint)
        )
        .accessibilityElement(children: .combine)
    }
}


// MARK: - Quick action tile

struct QuickActionTile: View {

    let icon: String
    let title: String
    let tint: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)

            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(HomePalette.text)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(colorScheme == .dark ? 0.15 : 0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(colorScheme == .dark ? 0.5 : 0.9), lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}


// MARK: - Tracker / calendar row (purple, list style)

struct TrackerRow: View {

    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HomePalette.purple)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(HomePalette.lavender)
                )

            Text(title)
                .font(.system(.subheadline).weight(.semibold))
                .foregroundStyle(HomePalette.text)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(HomePalette.purple.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(HomePalette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(HomePalette.lavenderBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Risk level wording

fileprivate enum RiskLevel {
    case low, moderate, elevated

    init(score: Double) {
        switch score {
        case ..<0.30: self = .low
        case ..<0.60: self = .moderate
        default:      self = .elevated
        }
    }

    var title: String {
        switch self {
        case .low:      return "Low"
        case .moderate: return "Moderate"
        case .elevated: return "Elevated"
        }
    }

    var advice: String {
        switch self {
        case .low:
            return "Your recent patterns look steady. Keep looking after your sleep, rest and mood."
        case .moderate:
            return "Some of your recent patterns suggest you may be under more strain. Be gentle with yourself, and consider checking in with someone you trust."
        case .elevated:
            return "Your recent patterns suggest you may be struggling. Please consider reaching out to your doctor, midwife or a mental health professional. You don't have to go through this alone."
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
        .environmentObject(AppEnvironment.shared)
}
