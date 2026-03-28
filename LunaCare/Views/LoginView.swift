//
//  LoginView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-10-09.
//  Updated by Fernanda
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel

    @State private var username          = ""
    @State private var password          = ""
    @State private var navigateToHome    = false
    @State private var navigateToRegister = false
    @State private var navigateToGuest   = false
    @State private var isLoading         = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Text("Welcome To")
                    .font(.title2)
                    .foregroundColor(.gray)
                Text("Luna Care")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.systemIndigo))

                VStack(spacing: 15) {
                    TextField("username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    SecureField("password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)

                if !auth.errorMessage.isEmpty {
                    Text(auth.errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button {
                    isLoading = true
                    auth.signIn(email: username, password: password)
                } label: {
                    HStack {
                        if isLoading { ProgressView().tint(.white) }
                        Text(isLoading ? "Logging in..." : "Login")
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
                .onChange(of: auth.isAuthenticated) { _, newValue in
                    isLoading = false
                    if newValue { navigateToHome = true }
                }
                .onChange(of: auth.errorMessage) { _, _ in
                    if !auth.errorMessage.isEmpty { isLoading = false }
                }
                .navigationDestination(isPresented: $navigateToHome) { HomeView() }
                Button {
                    navigateToGuest = true
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                        Text("Continue without an account")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                    .padding(.horizontal, 40)
                }
                .navigationDestination(isPresented: $navigateToGuest) {
                    GuestRegistrationView()
                }


                Button { navigateToRegister = true } label: {
                    Text("Create Account")
                        .underline()
                        .foregroundColor(Color(.systemIndigo))
                        .padding(.top, 10)
                }
                .navigationDestination(isPresented: $navigateToRegister) { RegistrationView() }

                Spacer()
            }
        }
    }
}

#Preview {
    LoginView().environmentObject(AuthViewModel())
}
