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

import SwiftUI
import FirebaseFirestore

struct HomeContentView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var health = AppleWatchDataStore.shared
    
    @State private var showingMLTestAlert = false
    @State private var mlTestMessage = ""

    // NEW upload state
    @State private var showingUploadAlert = false
    @State private var uploadMessage = ""
    @State private var isUploadingFakeData = false

    // repo instance
    private let repo = MeasurementRepository()

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
                                .environmentObject(auth)
                                .environmentObject(env)
                                .environmentObject(InsightsViewModel(auth: auth, env: env))
                        } label: {
                            QuickAccessButton(icon: "chart.bar.xaxis", title: "Insights")
                        }
                    }

                    // Trackers + Calendars (unchanged)
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

            // ALERT for upload result
            .alert("Fake Data Upload", isPresented: $showingUploadAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(uploadMessage)
            }

            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if !auth.email.isEmpty {
                            Text("Signed in as \(auth.email)")
                        }

                        // NEW menu action for uploading fake data
                        Button {
                            uploadFakeData()
                        } label: {
                            Label(isUploadingFakeData ? "Uploading..." : "Upload Fake Data",
                                  systemImage: "icloud.and.arrow.up")
                        }
                        .disabled(isUploadingFakeData)

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
                    return
                }
                #endif
                Task { await health.authorizeAndRefresh() }
            }
        }
    }

    // MARK: - Fake ML Test
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

    // MARK: - Upload Fake Data (Right now just uploading fake data since we don't have real apple watch data)
    @MainActor
    private func uploadFakeData() {
        guard !auth.uid.isEmpty else {
            uploadMessage = "No user signed in — can’t upload."
            showingUploadAlert = true
            return
        }
        guard !isUploadingFakeData else { return }
        isUploadingFakeData = true

        Task { @MainActor in
            defer { isUploadingFakeData = false }

            let fake30 = FakeStruct.highRisk30Days()
            do {
                let count = try await repo.upsertMany(uid: auth.uid, measurements: fake30)
                uploadMessage = "Uploaded \(count) fake day-measurements"
            } catch {
                let ns = error as NSError
                if ns.domain == FirestoreErrorDomain,
                   ns.code == FirestoreErrorCode.resourceExhausted.rawValue {
                    uploadMessage = """
                    Upload blocked by Firestore quota (resource exhausted).
                    This isn’t your code anymore — it’s the project plan limit.
                    """
                } else {
                    uploadMessage = "Upload failed: \(error.localizedDescription)"
                }
            }

            showingUploadAlert = true
        }
    }





    /// async/await wrapper for repo.upsert
    private func upsertAsync(uid: String, measurement: Measurement) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            repo.upsert(uid: uid, measurement: measurement) { err in
                if let err = err {
                    cont.resume(throwing: err)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }
}

    


#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
        .environmentObject(AppEnvironment.shared)
}
