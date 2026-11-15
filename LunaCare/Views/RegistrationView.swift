//
//  RegistrationView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-10-09.
//  Updated by Fernanda
//

import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var firstName: String
    @State private var lastName: String
    @State private var username        = ""
    @State private var password        = ""
    @State private var confirmPassword = ""

    @State private var localError = ""
    @State private var isLoading  = false

    /// When `true` the view was pushed from Settings (inside an existing HomeView),
    /// so a successful sign-up pops back instead of relying on ContentView's root swap.
    private let isFromSettings: Bool

    init(firstName: String = "", lastName: String = "", isFromSettings: Bool = false) {
        self._firstName    = State(initialValue: firstName)
        self._lastName     = State(initialValue: lastName)
        self.isFromSettings = isFromSettings
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Registration:")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(Color(.systemIndigo))

            VStack(spacing: 15) {
                TextField("First Name", text: $firstName)
                    .textFieldStyle(.roundedBorder)
                TextField("Last Name", text: $lastName)
                    .textFieldStyle(.roundedBorder)
                TextField("User Name (email)", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password Confirmation", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)

            if !localError.isEmpty || !auth.errorMessage.isEmpty {
                Text(localError.isEmpty ? auth.errorMessage : localError)
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
                guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty else {
                    localError = "Please fill in email and password."
                    return
                }
                guard password == confirmPassword else {
                    localError = "Passwords do not match."
                    return
                }
                isLoading  = true
                localError = ""
                auth.signUp(email: username,
                            password: password,
                            firstName: firstName,
                            lastName: lastName) { success in
                    isLoading = false
                    if success && isFromSettings {
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    if isLoading { ProgressView().tint(.white) }
                    Text(isLoading ? "Registering…" : "Register")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(.systemIndigo))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal, 40)
            }
            .disabled(isLoading)

            Spacer()
        }
        .onAppear { auth.errorMessage = "" }
    }
}

#Preview {
    RegistrationView().environmentObject(AuthViewModel())
}
