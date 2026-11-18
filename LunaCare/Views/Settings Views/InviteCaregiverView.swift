//
//  InviteCaregiverView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-18.
//

import SwiftUI

/// Sheet where the mother enters a family member's email and picks what they can see.
struct InviteCaregiverView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: CaregiversViewModel

    private static let relationships = ["Partner", "Parent", "Sibling", "Friend", "Other"]

    @State private var email = ""
    @State private var relationship = relationships[0]
    @State private var permissions = CaregiverPermissions(mood: true, symptoms: true, riskAlerts: true)
    @State private var isCreating = false
    @State private var invite: CaregiverInvite? = nil

    var body: some View {
        NavigationStack {
            Form {
                if let invite {
                    createdSection(invite)
                } else {
                    Section {
                        TextField("Email address", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Picker("Relationship", selection: $relationship) {
                            ForEach(Self.relationships, id: \.self) { Text($0) }
                        }
                    } footer: {
                        Text("We'll email them an invite. When they sign up as a family caregiver with this email, they'll be linked to you automatically.")
                    }
                    Section {
                        CaregiverPermissionToggles(permissions: $permissions)
                    } header: {
                        Text("They can see")
                    } footer: {
                        Text("You can change this any time in Family & Caregivers.")
                    }
                    if let error = vm.errorMessage {
                        Section { Text(error).foregroundColor(.red) }
                    }
                }
            }
            // Errors from this sheet are shown inline; don't re-show them on the screen behind it.
            .onDisappear { vm.errorMessage = nil }
            .navigationTitle("Invite Caregiver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if invite == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if isCreating {
                            ProgressView()
                        } else {
                            Button("Invite") { Task { await create() } }
                                .disabled(!CaregiverInvite.isValidEmail(email))
                        }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    private func createdSection(_ invite: CaregiverInvite) -> some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.green)
                Text("Invite emailed to")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(invite.email)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Backup code: \(invite.displayCode) · expires \(invite.expiresAt.formatted(.relative(presentation: .named)))")
                    .font(.footnote.monospaced())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                ShareLink(item: invite.shareMessage) {
                    Label("Share Invite", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(.systemIndigo))
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } footer: {
            Text("It may take a minute to arrive, so ask them to check spam too. You can also share the invite yourself. If they already have a caregiver account, they'll be linked next time they open the app.")
        }
    }

    private func create() async {
        isCreating = true
        defer { isCreating = false }
        invite = await vm.createInvite(email: email, relationship: relationship, permissions: permissions, uid: auth.uid)
    }
}
