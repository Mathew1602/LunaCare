//
//  CaregiversView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-15.
//

import SwiftUI

/// Lets the mother invite family members, choose what each one can see, or remove them.
struct CaregiversView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = CaregiversViewModel()
    @State private var caregiverToRemove: Caregiver? = nil
    @State private var isShowingInvite = false

    var body: some View {
        List {
            if vm.isLoading && vm.caregivers.isEmpty && vm.invites.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else if vm.caregivers.isEmpty && vm.invites.isEmpty {
                ContentUnavailableView {
                    Label("No caregivers yet", systemImage: "person.2")
                } description: {
                    Text("Invite a family member to follow your daily check-ins and be alerted if you may need extra support.")
                } actions: {
                    Button("Invite Caregiver") { isShowingInvite = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(.systemIndigo))
                }
                .listRowBackground(Color.clear)
            } else {
                if !vm.invites.isEmpty { pendingInvitesSection }
                ForEach(vm.caregivers) { caregiverSection($0) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Family & Caregivers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isShowingInvite = true } label: { Image(systemName: "person.badge.plus") }
                    .accessibilityLabel("Invite Caregiver")
            }
        }
        .sheet(isPresented: $isShowingInvite) { InviteCaregiverView(vm: vm) }
        .task { await vm.load(uid: auth.uid) }
        .refreshable { await vm.load(uid: auth.uid) }
        .confirmationDialog(
            "Remove \(caregiverToRemove?.displayName ?? "this caregiver")?",
            isPresented: Binding(get: { caregiverToRemove != nil }, set: { if !$0 { caregiverToRemove = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                guard let caregiver = caregiverToRemove else { return }
                Task { await vm.remove(caregiver, uid: auth.uid) }
            }
        } message: {
            Text("They will no longer see your reports or receive alerts.")
        }
        .alert("Something went wrong", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var pendingInvitesSection: some View {
        Section {
            ForEach(vm.invites) { invite in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(invite.email)
                            .font(.headline)
                        Text("\(invite.relationship) · expires \(invite.expiresAt.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    ShareLink(item: invite.shareMessage) { Image(systemName: "square.and.arrow.up") }
                        .buttonStyle(.borderless)
                }
                .swipeActions {
                    Button("Cancel", role: .destructive) { Task { await vm.cancel(invite) } }
                }
            }
        } header: {
            Text("Pending invites")
        } footer: {
            Text("Swipe left to cancel an invite.")
        }
    }

    private func caregiverSection(_ caregiver: Caregiver) -> some View {
        Section {
            CaregiverPermissionToggles(permissions: Binding(
                get: { caregiver.permissions },
                set: { permissions in
                    Task { await vm.update(permissions, for: caregiver, uid: auth.uid, motherName: auth.firstName) }
                }
            ))

            Button("Remove Caregiver", role: .destructive) { caregiverToRemove = caregiver }
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text(caregiver.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(caregiver.email)
                    .font(.caption)
            }
            .textCase(nil)
        }
        .disabled(vm.inProgressIds.contains(caregiver.id))
    }
}

/// The four sharing switches, used when inviting and when editing a caregiver.
struct CaregiverPermissionToggles: View {
    @Binding var permissions: CaregiverPermissions

    var body: some View {
        Toggle(isOn: $permissions.mood) { Label("Daily mood", systemImage: "face.smiling") }
        Toggle(isOn: $permissions.symptoms) { Label("Daily symptoms", systemImage: "list.clipboard") }
        Toggle(isOn: $permissions.riskAlerts) { Label("High-risk alerts", systemImage: "bell.badge") }
        Toggle(isOn: $permissions.doctorContact) { Label("My doctor's contact", systemImage: "stethoscope") }
    }
}

#Preview {
    NavigationStack {
        CaregiversView()
            .environmentObject(AuthViewModel())
    }
}
