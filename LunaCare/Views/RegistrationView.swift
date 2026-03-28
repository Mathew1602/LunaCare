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

    @State private var firstName       = ""
    @State private var lastName        = ""
    @State private var username        = ""
    @State private var password        = ""
    @State private var confirmPassword = ""
    @State private var navigateToHome  = false

    @State private var localError = ""
    @State private var isLoading  = false

    var body: some View {
        NavigationStack {
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
                    guard !firstName.isEmpty, !lastName.isEmpty else {
                        localError = "Please enter your first and last name."
                        return
                    }
                    guard !username.isEmpty, !password.isEmpty else {
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
                                lastName: lastName)
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
                .navigationDestination(isPresented: $navigateToHome) { HomeView() }

                Spacer()
            }
            .onChange(of: auth.isAuthenticated) { _, newValue in
                isLoading = false
                if newValue { navigateToHome = true }
            }
            .onChange(of: auth.errorMessage) { _, _ in
                if !auth.errorMessage.isEmpty { isLoading = false }
            }
        }
    }
}

#Preview {
    RegistrationView().environmentObject(AuthViewModel())
}
