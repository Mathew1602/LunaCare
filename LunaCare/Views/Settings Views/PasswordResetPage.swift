//
//  PasswordResetPage.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-03-08.
//

import Foundation
import SwiftUI

struct PasswordResetPage: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var isResetting = false
    @State private var showResetConfirmation = false
    @State private var resetError = ""

    var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 6
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Header
                VStack(spacing: 8) {
                    HStack {
                        Button(action: { isPresented = false }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("Back")
                            }
                        }
                        
                        Spacer()
                    }
                    
                    Text("Reset Password")
                        .font(.system(size: 28, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Create a new secure password for your account")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Email Display
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
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // MARK: - Current Password Section
                        VStack(spacing: 16) {
                            Text("Verify Current Password")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Current Password")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                HStack {
                                    if showPassword {
                                        TextField("Enter current password", text: $currentPassword)
                                    } else {
                                        SecureField("Enter current password", text: $currentPassword)
                                    }
                                    
                                    Button(action: { showPassword.toggle() }) {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 14))
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        
                        // MARK: - New Password Section
                        VStack(spacing: 16) {
                            Text("New Password")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                HStack {
                                    if showPassword {
                                        TextField("Enter new password", text: $newPassword)
                                    } else {
                                        SecureField("Enter new password", text: $newPassword)
                                    }
                                    
                                    Button(action: { showPassword.toggle() }) {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 14))
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Confirm Password")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                HStack {
                                    if showPassword {
                                        TextField("Confirm new password", text: $confirmPassword)
                                    } else {
                                        SecureField("Confirm new password", text: $confirmPassword)
                                    }
                                    
                                    if !confirmPassword.isEmpty {
                                        if newPassword == confirmPassword {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 14))
                                        } else {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .font(.system(size: 14))
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password Requirements")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                RequirementRow(
                                    text: "At least 6 characters",
                                    isMet: newPassword.count >= 6
                                )
                                
                                RequirementRow(
                                    text: "Passwords match",
                                    isMet: !newPassword.isEmpty && newPassword == confirmPassword
                                )
                            }
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        // MARK: - Error Message
                        if !resetError.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                
                                Text(resetError)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.red)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemRed).opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                // MARK: - Action Buttons
                VStack(spacing: 12) {
                    Button(action: resetPassword) {
                        if isResetting {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(.white)
                                
                                Text("Resetting...")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemIndigo).opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        } else {
                            Text("Reset Password")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemIndigo))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(!isFormValid || isResetting)
                    
                    Button(action: { isPresented = false }) {
                        Text("Cancel")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.black)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemBackground))
            .alert("Password Reset", isPresented: $showResetConfirmation) {
                Button("OK") {
                    isPresented = false
                }
            } message: {
                Text("Your password has been reset successfully.")
            }
        }
    }
    
    private func resetPassword() {
        resetError = ""
        isResetting = true
        
        UserRepository().resetPassword(
            email: authViewModel.email,
            currentPassword: currentPassword,
            newPassword: newPassword
        ) { error in
            DispatchQueue.main.async {
                isResetting = false
                if let error = error {
                    resetError = error.localizedDescription
                } else {
                    showResetConfirmation = true
                }
            }
        }
    }
}

// MARK: - Helper Components

struct RequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .green : .gray)
                .font(.system(size: 14, weight: .semibold))
            
            Text(text)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(isMet ? .black : .gray)
            
            Spacer()
        }
    }
}

#Preview {
    PasswordResetPage(isPresented: .constant(true))
        .environmentObject(AuthViewModel.preview)
}
