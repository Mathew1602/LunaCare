//
//  CaregiverHomeView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-16.
//

import SwiftUI

/// Root of the caregiver app. Shown instead of `HomeView` when the signed-in user is a caregiver.
struct CaregiverHomeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var vm = CaregiverHomeViewModel()

    var body: some View {
        TabView {
            CaregiverTodayView(vm: vm)
                .tabItem { Label("Today", systemImage: "sun.max") }

            CaregiverHistoryView(vm: vm)
                .tabItem { Label("History", systemImage: "calendar") }

            CaregiverSupportView(vm: vm)
                .tabItem { Label("Support", systemImage: "heart.text.square") }

            CaregiverSettingsView(vm: vm)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Color(.systemIndigo))
        .task { await vm.load(caregiverUid: auth.uid) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await vm.load(caregiverUid: auth.uid) } }
        }
        .sheet(isPresented: $vm.isShowingAlerts) { CaregiverAlertsView(vm: vm) }
        .alert("Something went wrong", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
}

/// Shared tab chrome: navigation title, alerts bell, mother switcher, refresh, and the "not linked" state.
struct CaregiverTab<Content: View>: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var vm: CaregiverHomeViewModel
    let title: String
    @ViewBuilder let content: (LinkedMother) -> Content

    var body: some View {
        NavigationStack {
            Group {
                if let mother = vm.selectedMother {
                    content(mother)
                } else if vm.isLoading {
                    ProgressView()
                } else {
                    ContentUnavailableView(
                        "Not linked yet",
                        systemImage: "person.2.slash",
                        description: Text("When a mother invites you, her daily reports will appear here.")
                    )
                }
            }
            .navigationTitle(title)
            .toolbar {
                if vm.mothers.count > 1 {
                    ToolbarItem(placement: .topBarLeading) { motherPicker }
                }
                if vm.selectedMother != nil {
                    ToolbarItem(placement: .topBarTrailing) { alertsButton }
                }
            }
            .refreshable { await vm.load(caregiverUid: auth.uid) }
        }
    }

    private var alertsButton: some View {
        Button { vm.isShowingAlerts = true } label: {
            Image(systemName: vm.unseenAlertCount > 0 ? "bell.badge.fill" : "bell")
                .symbolRenderingMode(vm.unseenAlertCount > 0 ? .multicolor : .monochrome)
        }
        .accessibilityLabel(vm.unseenAlertCount > 0 ? "Alerts, \(vm.unseenAlertCount) new" : "Alerts")
    }

    private var motherPicker: some View {
        Menu {
            ForEach(vm.mothers) { mother in
                Button(mother.name) { Task { await vm.select(mother) } }
            }
        } label: {
            Label(vm.selectedMother?.name ?? "Select", systemImage: "person.crop.circle")
        }
    }
}

#Preview {
    CaregiverHomeView()
        .environmentObject(AuthViewModel.preview)
        .environmentObject(AppEnvironment.shared)
}
