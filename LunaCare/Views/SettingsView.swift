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

    @State private var showSyncConfirmAlert  = false
    @State private var showCloudToLocalAlert = false
    @State private var isSyncingDown         = false
    private var isGuest: Bool { auth.noAccount }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Profile")) {
                    if !isGuest {
                        NavigationLink("Account") { AccountPage() }
                        NavigationLink("My Care Team") { CareTeamView() }
                    } else {
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
                        } label: {
                            Label("Create an Account", systemImage: "person.badge.plus")
                                .foregroundColor(Color(.systemIndigo))
                        }
                    }
                }

                Section(header: Text("Privacy & Security")) {
                    if !isGuest {
                        NavigationLink("Data Privacy") { DataPrivacyView() }
                    }
                    NavigationLink("Data Export") { DataExportView() }

                    if isGuest {
                        guestCloudSyncRow
                    } else {
                        cloudSyncToggle
                        syncStatus
                    }
                }

                Section(header: Text("App Preferences")) {
                    NavigationLink("Notifications") { NotificationSettingsView() }
                    Picker("Theme", selection: $env.selectedTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue)
                        }
                    }
                }

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
        }
    }

    private var guestCloudSyncRow: some View {
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
    }

    private var cloudSyncToggle: some View {
        Toggle(isOn: Binding(
            get: { env.isCloudSyncOn },
            set: { newValue in
                if newValue {
                    showSyncConfirmAlert = true
                } else {
                    showCloudToLocalAlert = true
                }
            }
        )) { Text("Cloud Sync") }
        .disabled(env.isSyncing || auth.uid.isEmpty)
        .alert("Sync to Cloud?", isPresented: $showSyncConfirmAlert) {
            Button("Sync to Cloud") {
                let uid = auth.uid
                guard !uid.isEmpty else { return }
                isSyncingDown = false
                SyncManager.shared.applyCloudSyncPreference(uid: uid, isOn: true, env: env)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your data is currently stored locally. Are you sure you want to sync it to the cloud?")
        }
        .alert("Download Cloud Data?", isPresented: $showCloudToLocalAlert) {
            Button("Download to Device") {
                let uid = auth.uid
                guard !uid.isEmpty else { return }
                SyncManager.shared.applyCloudSyncPreference(uid: uid, isOn: false, env: env)
                isSyncingDown = true
                SyncManager.shared.startDownload(uid: uid, env: env) {
                    isSyncingDown = false
                }
            }
            Button("Turn Off Only") {
                let uid = auth.uid
                guard !uid.isEmpty else { return }
                SyncManager.shared.applyCloudSyncPreference(uid: uid, isOn: false, env: env)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Would you like to download your cloud data to this device before turning off cloud sync?")
        }
    }

    @ViewBuilder
    private var syncStatus: some View {
        if env.isSyncing {
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: env.syncHasData ? env.syncProgress : nil)
                    .progressViewStyle(.linear)
                Text(isSyncingDown ? "Downloading your data…" : "Uploading your data…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        } else if let error = env.lastSyncError {
            VStack(alignment: .leading, spacing: 6) {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundColor(.orange)
                if env.isCloudSyncOn {
                    Button("Retry Sync") {
                        isSyncingDown = false
                        SyncManager.shared.startUpload(uid: auth.uid, env: env)
                    }
                    .font(.footnote.weight(.semibold))
                }
            }
        } else {
            Text(env.isCloudSyncOn ? "Synced to Cloud" : "Local Only")
                .font(.footnote)
                .foregroundColor(.secondary)
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
