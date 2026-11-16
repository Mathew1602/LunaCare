//
//  CaregiversView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-15.
//

import SwiftUI

/// Lets the mother choose what each linked family member can see, or remove them.
struct CaregiversView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = CaregiversViewModel()
    @State private var caregiverToRemove: Caregiver? = nil

    var body: some View {
        List {
            if vm.isLoading && vm.caregivers.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else if vm.caregivers.isEmpty {
                ContentUnavailableView(
                    "No caregivers yet",
                    systemImage: "person.2",
                    description: Text("Family members you link to LunaCare will appear here.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(vm.caregivers) { caregiverSection($0) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Family & Caregivers")
        .navigationBarTitleDisplayMode(.inline)
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

    private func caregiverSection(_ caregiver: Caregiver) -> some View {
        Section {
            permissionToggle("Daily mood", systemImage: "face.smiling", \.mood, for: caregiver)
            permissionToggle("Daily symptoms", systemImage: "list.clipboard", \.symptoms, for: caregiver)
            permissionToggle("High-risk alerts", systemImage: "bell.badge", \.riskAlerts, for: caregiver)
            permissionToggle("My doctor's contact", systemImage: "stethoscope", \.doctorContact, for: caregiver)

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

    private func permissionToggle(
        _ title: String,
        systemImage: String,
        _ keyPath: WritableKeyPath<CaregiverPermissions, Bool>,
        for caregiver: Caregiver
    ) -> some View {
        Toggle(isOn: Binding(
            get: { caregiver.permissions[keyPath: keyPath] },
            set: { newValue in
                var permissions = caregiver.permissions
                permissions[keyPath: keyPath] = newValue
                Task { await vm.update(permissions, for: caregiver, uid: auth.uid, motherName: auth.firstName) }
            }
        )) {
            Label(title, systemImage: systemImage)
        }
    }
}

#Preview {
    NavigationStack {
        CaregiversView()
            .environmentObject(AuthViewModel())
    }
}
