//
//  AccountPage.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-03-08.
//

import Foundation
import SwiftUI

struct AccountPage: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showPasswordResetSheet = false
    @State private var showSaveConfirmation = false
    @State private var editFirstName = ""
    @State private var editLastName = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("Account Settings")
                        .font(.system(size: 28, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Manage your profile and security")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            Text("Profile Information")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // First Name
                            VStack(alignment: .leading, spacing: 6) {
                                Text("First Name")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                TextField("First name", text: $editFirstName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.vertical, 4)
                            }
                            
                            // Last Name
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Last Name")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                TextField("Last name", text: $editLastName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.vertical, 4)
                            }
                            
                            // Email (Read-only)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                HStack {
                                    Text(authViewModel.email)
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 14))
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // MARK: - Security Section
                        VStack(spacing: 12) {
                            Text("Security")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button(action: {
                                showPasswordResetSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 16))
                                    
                                    Text("Reset Password")
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemIndigo))
                                .cornerRadius(10)
                            }
                        }
                        
                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                // MARK: - Save Button
                VStack(spacing: 12) {
                    Button(action: saveProfile) {
                        if isSaving {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(.white)
                                
                                Text("Saving...")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemIndigo).opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        } else {
                            Text("Save Changes")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemIndigo))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(isSaving)
                    
                    Button(action: { authViewModel.signOut() }) {
                        Text("Sign Out")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemBackground))
            .sheet(isPresented: $showPasswordResetSheet) {
                PasswordResetPage(isPresented: $showPasswordResetSheet)
            }
            .alert("Profile Updated", isPresented: $showSaveConfirmation) {
                Button("OK") { }
            } message: {
                Text("Your profile has been saved successfully.")
            }
            .onAppear {
                editFirstName = authViewModel.firstName
                editLastName = authViewModel.lastName
            }
            .onChange(of: authViewModel.firstName) { _, newValue in
                editFirstName = newValue
            }
            .onChange(of: authViewModel.lastName) { _, newValue in
                editLastName = newValue
            }
        }
    }
    
    
    private func saveProfile() {
        isSaving = true
        
        // Update view model
        authViewModel.firstName = editFirstName.trimmingCharacters(in: .whitespaces)
        authViewModel.lastName = editLastName.trimmingCharacters(in: .whitespaces)
        
        // Save to Firestore
        UserRepository().updateUserProfile(
            uid: authViewModel.uid,
            firstName: editFirstName,
            lastName: editLastName
        ) { error in
            DispatchQueue.main.async {
                isSaving = false
                if error == nil {
                    showSaveConfirmation = true
                } else {
                    authViewModel.errorMessage = "Failed to save profile. Please try again."
                }
            }
        }
    }
}

#Preview {
    AccountPage()
}
