//
//  SettingsView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-10-09.
//  Updated by Fernanda

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var env:  AppEnvironment

    @State private var isCloudSyncOn: Bool = false
    @State private var statusText: String  = ""
    @State private var showSyncConfirmAlert = false
    private var isGuest: Bool { auth.noAccount }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Profile")) {
                    if !isGuest {
                        NavigationLink {
                            AccountPage()
                                .environmentObject(auth)
                        } label: {
                            Text("Account")
                        }
                        NavigationLink("Caregiver Links") { Text("Caregiver Links") }
                    } else {
                        // Guest: show name, prompt to create account
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(.secondary)
                            Text(auth.displayName.isEmpty ? "Guest" : auth.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("Local only")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        NavigationLink {
                            RegistrationView(
                                firstName: auth.firstName,
                                lastName: auth.lastName,
                                isFromSettings: true
                            )
                            .environmentObject(auth)
                        } label: {
                            Label("Create an Account", systemImage: "person.badge.plus")
                                .foregroundColor(Color(.systemIndigo))
                        }
                    }
                }

                // ── Privacy & Security ────────────────────────────────────
                Section(header: Text("Privacy & Security")) {
                    if !isGuest {
                        NavigationLink("Data Privacy") { Text("Data Privacy Settings") }
                        NavigationLink("Data Export")  { Text("Data Export Options")  }
                    }

                    // Cloud Sync — disabled for guests
                    if isGuest {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Cloud Sync")
                                Spacer()
                                Toggle("", isOn: .constant(false))
                                    .disabled(true)
                                    .labelsHidden()
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "lock.icloud")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("Create an account to sync with cloud")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    } else {
                        Toggle(isOn: Binding(
                            get: { isCloudSyncOn },
                            set: { newValue in
                                if newValue {
                                    showSyncConfirmAlert = true
                                } else {
                                    isCloudSyncOn = false
                                    let uid = auth.uid
                                    guard !uid.isEmpty else { return }
                                    SyncManager.shared.applyCloudSyncPreference(uid: uid, isOn: false, env: env)
                                    statusText = "Local Only"
                                }
                            }
                        )) { Text("Cloud Sync") }
                        .disabled(env.isSyncing)
                        .alert("Sync to Cloud?", isPresented: $showSyncConfirmAlert) {
                            Button("Sync to Cloud") {
                                isCloudSyncOn = true
                                let uid = auth.uid
                                guard !uid.isEmpty else { return }
                                SyncManager.shared.applyCloudSyncPreference(uid: uid, isOn: true, env: env)
                                statusText = "Syncing..."
                            }
                            Button("Cancel", role: .cancel) { }
                        } message: {
                            Text("Your data is currently stored locally. Are you sure you want to sync it to the cloud?")
                        }

                        if env.isSyncing {
                            VStack(alignment: .leading, spacing: 4) {
                                ProgressView(value: env.syncProgress)
                                    .progressViewStyle(.linear)
                                Text("Uploading your data…")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        } else if !statusText.isEmpty {
                            Text(statusText)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // ── App Preferences ───────────────────────────────────────
                Section(header: Text("App Preferences")) {
                    NavigationLink("Notifications") { Text("Notification Settings") }
                    Picker("Theme", selection: $env.selectedTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue)
                        }
                    }
                    NavigationLink("Language") { Text("Language Settings") }
                }

                // ── Account ───────────────────────────────────────────────
                Section {
                    if !auth.displayName.isEmpty {
                        Text(isGuest
                             ? "Browsing as \(auth.displayName) (local only)"
                             : "Signed in as \(auth.displayName)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else if !auth.email.isEmpty {
                        Text("Signed in as \(auth.email)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    Button(isGuest ? "Exit Guest Mode" : "Sign Out",
                           role: .destructive) {
                        auth.signOut()
                    }
                }
            }
            .navigationTitle("Settings")
            .listStyle(.insetGrouped)
            .onChange(of: env.isSyncing) { _, syncing in
                if !syncing && isCloudSyncOn {
                    statusText = "Synced to Cloud"
                }
            }
            .onAppear {
                guard !isGuest else {
                    statusText = "Local Only"
                    return
                }
                let uid = auth.uid
                guard !uid.isEmpty else { return }
                UserRepository().fetchCloudSync(uid: uid) { cloudOn in
                    isCloudSyncOn   = cloudOn
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

#Preview("Guest mode") {
    SettingsView()
        .environmentObject(AuthViewModel.previewGuest)
        .environmentObject(AppEnvironment.shared)
}
