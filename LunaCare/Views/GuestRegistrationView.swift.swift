//
//  GuestRegistrationView.swift
//  LunaCare
//
//  Created by Mathew Boyd 27/03/2026
//

import SwiftUI

struct GuestRegistrationView: View {
    @EnvironmentObject var auth: AuthViewModel
    private let syncManager = SyncManager.shared
    @EnvironmentObject var env:  AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var firstName   = ""
    @State private var lastName    = ""
    @State private var localError  = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 6) {
                    Text("Continue Without Account")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(.systemIndigo))
                        .multilineTextAlignment(.center)

                    Text("Your data stays on this device only.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)

                HStack(spacing: 10) {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.orange)
                    Text("Local only — create an account to sync with cloud")
                        .font(.footnote)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
                .background(Color.orange.opacity(0.10))
                .cornerRadius(10)
                .padding(.horizontal, 40)

                VStack(spacing: 15) {
                    TextField("First Name", text: $firstName)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)

                    TextField("Last Name", text: $lastName)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)

                if !localError.isEmpty {
                    Text(localError)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button {
                    guard !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        localError = "Please enter your first and last name."
                        return
                    }
                    localError = ""
                    auth.signInAsGuest(firstName: firstName, lastName: lastName)
                    syncManager.applyCloudSyncPreference(uid: "", isOn: false, env: env)
                    
                    // ContentView reacts to auth.noAccount becoming true
                } label: {
                    Text("Continue Locally")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemIndigo))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal, 40)
                }

               
                Button {
                    dismiss()
                } label: {
                    Text("Back to Login")
                        .underline()
                        .foregroundColor(Color(.systemIndigo))
                        .padding(.top, 6)
                }

                Spacer()
            }
        }
    }
}

#Preview {
    GuestRegistrationView()
        .environmentObject(AuthViewModel.previewGuest)
}
