//
//  LoginView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-10-09.
//

import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var navigateToHome = false
    @State private var navigateToRegister = false

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
                    SecureField("password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                
                Button {
                    navigateToHome = true
                } label: {
                    Text("Login")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemIndigo))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal, 40)
                }
                .navigationDestination(isPresented: $navigateToHome) {
                    HomeView()
                }
                
                Button {
                    // Google login dummy action
                } label: {
                    HStack {
                        Image(systemName: "globe")
                        Text("Log in with Google")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                    .padding(.horizontal, 40)
                }
                
                Button {
                    navigateToRegister = true
                } label: {
                    Text("Create Account")
                        .underline()
                        .foregroundColor(Color(.systemIndigo))
                        .padding(.top, 10)
                }
                .navigationDestination(isPresented: $navigateToRegister) {
                    RegistrationView()
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    LoginView()
}
