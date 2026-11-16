//
//  CaregiverSettingsView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-16.
//

import SwiftUI

struct CaregiverSettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var env: AppEnvironment
    @ObservedObject var vm: CaregiverHomeViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    NavigationLink("Account") { AccountPage() }
                }

                ForEach(vm.mothers) { mother in
                    sharedWithYouSection(for: mother)
                }

                Section("App Preferences") {
                    Picker("Theme", selection: $env.selectedTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue)
                        }
                    }
                }

                Section {
                    if !auth.displayName.isEmpty {
                        Text("Signed in as \(auth.displayName)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Button("Sign Out", role: .destructive) { auth.signOut() }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
    }

    private func sharedWithYouSection(for mother: LinkedMother) -> some View {
        Section {
            sharedRow("Daily mood", isShared: mother.permissions.mood)
            sharedRow("Daily symptoms", isShared: mother.permissions.symptoms)
            sharedRow("High-risk alerts", isShared: mother.permissions.riskAlerts)
            sharedRow("Doctor's contact", isShared: mother.permissions.doctorContact)
        } header: {
            Text("What \(mother.name) shares with you")
        } footer: {
            Text("Only \(mother.name) can change what she shares.")
        }
    }

    private func sharedRow(_ title: String, isShared: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isShared ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(isShared ? .green : .secondary)
                .accessibilityLabel(isShared ? "Shared" : "Not shared")
        }
    }
}
