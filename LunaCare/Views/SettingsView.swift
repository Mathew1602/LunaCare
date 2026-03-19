//
//  SettingsView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-10-09.
//  Updated by Fernanda

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var env: AppEnvironment

    @State private var isCloudSyncOn: Bool = false
    @State private var statusText: String = ""


    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Profile")) {
                    NavigationLink {
                        AccountPage()
                            .environmentObject(auth)
                    } label: {
                        Text("Account")
                    }
                    
                    NavigationLink("Caregiver Links") { Text("Caregiver Links") }
                }
                

                Section(header: Text("Privacy & Security")) {
                    NavigationLink("Data Privacy") { Text("Data Privacy Settings") }
                    NavigationLink("Data Export") { Text("Data Export Options") }

                    Toggle(isOn: $isCloudSyncOn) { Text("Cloud Sync") }
                        .onChange(of: isCloudSyncOn) { newValue in
                            let uid = auth.uid
                            guard !uid.isEmpty else { return }
                            SyncManager.shared.applyCloudSyncPreference(uid: uid, isOn: newValue, env: env)
                            statusText = newValue ? "Synced to Cloud" : "Local Only"
                        }

                    if !statusText.isEmpty {
                        Text(statusText)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("App Preferences")) {
                    NavigationLink("Notifications") { Text("Notification Settings") }
                    Picker("Theme", selection: $env.selectedTheme) {
                         ForEach(AppTheme.allCases, id: \.self) { theme in
                             Text(theme.rawValue)
                         }
                     }
                    NavigationLink("Language") { Text("Language Settings") }
                }

                Section {
                    if !auth.displayName.isEmpty {
                        Text("Signed in as \(auth.displayName)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else if !auth.email.isEmpty {
                        Text("Signed in as \(auth.email)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Button("Sign Out", role: .destructive) { auth.signOut() }
                }
            }
            .navigationTitle("Settings")
            .listStyle(.insetGrouped)
            .onAppear {
                let uid = auth.uid
                guard !uid.isEmpty else { return }
                UserRepository().fetchCloudSync(uid: uid) { cloudOn in
                    isCloudSyncOn = cloudOn
                    env.isCloudSyncOn = cloudOn
                    statusText = cloudOn ? "Synced to Cloud" : "Local Only"
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
        .environmentObject(AppEnvironment.shared)
}
