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
    @StateObject private var vm = CaregiverHomeViewModel()

    var body: some View {
        TabView {
            CaregiverTodayView(vm: vm)
                .tabItem { Label("Today", systemImage: "sun.max") }

            CaregiverHistoryView(vm: vm)
                .tabItem { Label("History", systemImage: "calendar") }

            CaregiverSupportView(vm: vm)
                .tabItem { Label("Support", systemImage: "heart.text.square") }
        }
        .tint(Color(.systemIndigo))
        .task { await vm.load(caregiverUid: auth.uid) }
        .alert("Something went wrong", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
}

/// Shared tab chrome: navigation title, mother switcher, refresh, and the "not linked" state.
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
                    ToolbarItem(placement: .topBarTrailing) { motherPicker }
                }
            }
            .refreshable { await vm.load(caregiverUid: auth.uid) }
        }
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
}
