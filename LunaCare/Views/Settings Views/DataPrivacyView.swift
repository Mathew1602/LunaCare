//
//  DataPrivacyView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-10-08.
//

import SwiftUI

private struct StoredDataCategory: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let collection: String?
}

private let storedCategories: [StoredDataCategory] = [
    .init(id: "mood", title: "Mood Logs", detail: "Daily mood check-ins from the app or Apple Watch.", icon: "face.smiling", collection: "mood_logs"),
    .init(id: "symptoms", title: "Symptom Logs", detail: "Fatigue, bleeding, hair loss, appetite and sleep trouble.", icon: "cross.case", collection: "symptom_logs"),
    .init(id: "measurements", title: "Health Measurements", detail: "Sleep, heart, activity and weight from HealthKit and Apple Watch.", icon: "heart.text.square", collection: "measurements"),
    .init(id: "insights", title: "Insights", detail: "Weekly trend summaries generated from your data.", icon: "chart.bar.xaxis", collection: "insights"),
    .init(id: "comments", title: "Doctor Comments", detail: "Notes your approved doctors left on your stats.", icon: "text.bubble", collection: "doctor_comments"),
    .init(id: "profile", title: "Profile", detail: "Your name and email address.", icon: "person.crop.circle", collection: nil),
]

struct DataPrivacyView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var env: AppEnvironment
    @StateObject private var vm = DataPrivacyViewModel()
    @State private var doctorToRevoke: Doctor? = nil
    @State private var showDeleteSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if vm.isLoading && vm.counts.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let error = vm.errorMessage {
                    PrivacyCard {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } else {
                    storedDataSection
                    accessSection
                    cloudSyncSection
                    consentSection
                    onDeviceSection
                    dangerZone
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Data Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(uid: auth.uid) }
        .refreshable { await vm.load(uid: auth.uid) }
        .confirmationDialog(
            "Revoke access for \(doctorToRevoke?.displayName ?? "this doctor")?",
            isPresented: Binding(get: { doctorToRevoke != nil }, set: { if !$0 { doctorToRevoke = nil } }),
            titleVisibility: .visible
        ) {
            Button("Revoke Access", role: .destructive) {
                guard let doctor = doctorToRevoke else { return }
                Task { await vm.revoke(doctor, uid: auth.uid) }
            }
        } message: {
            Text("They will no longer be able to view your LunaCare data.")
        }
        .alert("Something went wrong", isPresented: Binding(get: { vm.actionError != nil }, set: { if !$0 { vm.actionError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.actionError ?? "")
        }
        .sheet(isPresented: $showDeleteSheet) {
            DeleteAccountSheet(vm: vm)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your Data & Privacy")
                .font(.title2.bold())
            Text("See what LunaCare stores, who can see it, and control how it's used.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var storedDataSection: some View {
        PrivacySection(title: "What LunaCare Stores") {
            PrivacyCard {
                VStack(spacing: 14) {
                    ForEach(storedCategories) { category in
                        HStack(alignment: .top, spacing: 12) {
                            PrivacyIcon(name: category.icon)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title).font(.subheadline.weight(.semibold))
                                Text(category.detail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                if let collection = category.collection {
                                    Text("\(vm.counts[collection] ?? 0)")
                                        .font(.subheadline.monospacedDigit().weight(.semibold))
                                }
                                storageBadge
                            }
                        }
                    }
                }
            }
        }
    }

    private var storageBadge: some View {
        let cloud = env.isCloudSyncOn
        return Text(cloud ? "Cloud" : "On device")
            .font(.caption2.weight(.semibold))
            .foregroundColor(cloud ? Color(.systemIndigo) : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill((cloud ? Color(.systemIndigo) : Color.secondary).opacity(0.12)))
    }

    private var accessSection: some View {
        PrivacySection(title: "Who Can See It") {
            PrivacyCard {
                VStack(alignment: .leading, spacing: 14) {
                    if vm.doctors.isEmpty {
                        Text("No doctors currently have access to your data.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    ForEach(vm.doctors) { doctor in
                        HStack(spacing: 12) {
                            PrivacyIcon(name: "stethoscope")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doctor.displayName).font(.subheadline.weight(.semibold))
                                Text("Can view all data above · \(doctor.specialty)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if vm.revokingDoctorIds.contains(doctor.id) {
                                ProgressView()
                            } else {
                                Button("Revoke", role: .destructive) { doctorToRevoke = doctor }
                                    .font(.footnote.weight(.semibold))
                                    .buttonStyle(.bordered)
                            }
                        }
                    }

                    Divider()

                    NavigationLink {
                        CareTeamView().environmentObject(auth)
                    } label: {
                        HStack {
                            PrivacyIcon(name: "hourglass")
                            Text(vm.pendingCount == 0 ? "No pending access requests" : "\(vm.pendingCount) pending access request\(vm.pendingCount == 1 ? "" : "s")")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Label("No one else — not LunaCare staff or other users — can access your data.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var cloudSyncSection: some View {
        PrivacySection(title: "Cloud Sync") {
            PrivacyCard {
                HStack(alignment: .top, spacing: 12) {
                    PrivacyIcon(name: env.isCloudSyncOn ? "icloud" : "internaldrive")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(env.isCloudSyncOn ? "Cloud sync is on" : "Cloud sync is off")
                            .font(.subheadline.weight(.semibold))
                        Text(env.isCloudSyncOn
                             ? "Your data is stored securely in the cloud with your account, so your approved doctors can see it."
                             : "Your data stays on this device. Your doctors won't see anything new until you turn sync on.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Change this with the Cloud Sync toggle in Settings.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var consentSection: some View {
        PrivacySection(title: "Consent") {
            PrivacyCard {
                VStack(alignment: .leading, spacing: 14) {
                    consentToggle(
                        title: "Share my data with approved doctors",
                        detail: "When off, your doctors' portal will not show your data, even if they're approved.",
                        isOn: vm.consent.shareWithDoctors,
                        key: .shareWithDoctors
                    )
                    Divider()
                    consentToggle(
                        title: "Use my data for risk insights",
                        detail: "When off, LunaCare won't calculate your PPD risk score.",
                        isOn: vm.consent.riskInsights,
                        key: .riskInsights
                    )
                    if let updated = vm.consent.updatedAt {
                        Text("Last updated \(updated.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func consentToggle(title: String, detail: String, isOn: Bool, key: ConsentKey) -> some View {
        Toggle(isOn: Binding(
            get: { isOn },
            set: { value in Task { await vm.setConsent(key, to: value, uid: auth.uid) } }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Color(.systemIndigo))
    }

    private var onDeviceSection: some View {
        PrivacySection(title: "How Your Data Is Used") {
            PrivacyCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Your PPD risk score is calculated on your phone. The model never sends your data anywhere.", systemImage: "iphone")
                    Label("HealthKit data is only read with your permission. Manage it in iOS Settings → Health.", systemImage: "heart")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }

    private var dangerZone: some View {
        PrivacySection(title: "Danger Zone") {
            Button(role: .destructive) {
                showDeleteSheet = true
            } label: {
                Label("Delete Account & Data", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.1)))
            }
        }
    }
}

private struct DeleteAccountSheet: View {
    @ObservedObject var vm: DataPrivacyViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This permanently deletes your account and everything stored with it:")
                    Label("All mood logs, symptom logs and health measurements", systemImage: "trash")
                    Label("Insights and doctor comments", systemImage: "trash")
                    Label("Access for all your doctors", systemImage: "person.crop.circle.badge.xmark")
                    Label("Data saved on this device", systemImage: "iphone")
                    Text("This can't be undone.").bold().foregroundColor(.red)
                }
                .font(.subheadline)

                Section("Confirm with your password") {
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                    if let error = vm.deleteError {
                        Text(error).font(.footnote).foregroundColor(.red)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            if await vm.deleteAccount(password: password) { dismiss() }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.isDeleting {
                                ProgressView()
                            } else {
                                Text("Delete My Account").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(password.isEmpty || vm.isDeleting)
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(vm.isDeleting)
                }
            }
            .interactiveDismissDisabled(vm.isDeleting)
            .onAppear { vm.deleteError = nil }
        }
    }
}

private struct PrivacySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }
}

private struct PrivacyCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }
}

private struct PrivacyIcon: View {
    let name: String

    var body: some View {
        Image(systemName: name)
            .font(.subheadline)
            .foregroundColor(Color(.systemIndigo))
            .frame(width: 34, height: 34)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemIndigo).opacity(0.1)))
    }
}
