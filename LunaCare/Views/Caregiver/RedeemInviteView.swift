//
//  RedeemInviteView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-18.
//

import SwiftUI

/// Sheet where a caregiver enters the code a mother shared with them.
struct RedeemInviteView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: CaregiverHomeViewModel

    @State private var code = ""
    @State private var isRedeeming = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("K7P-2QX", text: $code)
                        .font(.title2.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .submitLabel(.join)
                        .onSubmit { Task { await redeem() } }
                } header: {
                    Text("Invite code")
                } footer: {
                    Text("The backup code from her invite. It only works for the email she invited, works once, and expires after 48 hours.")
                }

                if let error = vm.redeemError {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .navigationTitle("Join with a Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isRedeeming {
                        ProgressView()
                    } else {
                        Button("Join") { Task { await redeem() } }
                            .disabled(code.isEmpty)
                    }
                }
            }
            .onAppear {
                vm.redeemError = nil
                isFocused = true
            }
        }
    }

    private func redeem() async {
        isRedeeming = true
        defer { isRedeeming = false }
        if await vm.redeemInvite(code: code, caregiverUid: auth.uid) {
            dismiss()
        }
    }
}
