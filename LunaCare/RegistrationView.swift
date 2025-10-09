//
//  RegistrationView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-10-09.
//

import SwiftUI

struct RegistrationView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var navigateToHome = false

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
                    TextField("User Name", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Password Confirmation", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                
                Button {
                    navigateToHome = true
                } label: {
                    Text("Register")
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
                
                Spacer()
            }
        }
    }
}

#Preview {
    RegistrationView()
}

