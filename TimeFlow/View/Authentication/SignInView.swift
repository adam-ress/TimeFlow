//
//  SignInView.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/20/25.
//

import SwiftUI

struct SignInView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(ContentModel.self) private var contentModel
    
    let email: String
    
    @State private var password = ""
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var showPassword = false
    @State private var showingResetConfirmation = false
    @State private var isResettingPassword = false

    private var isFormValid: Bool {
        !password.isEmpty
    }

    var body: some View {
        ZStack {
            // Modern background gradient matching the app theme and adapting to color scheme
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    AppTheme.Colors.accent.opacity(0.1),
                    AppTheme.Colors.secondary.opacity(0.2),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Header section
                    VStack(spacing: 16) {
                        // Back button
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Back")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(Color(.secondaryLabel))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        
                        // Icon and title
                        VStack(spacing: 20) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AppTheme.Colors.accent,
                                            AppTheme.Colors.accent.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "person.crop.circle")
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundColor(.white)
                                )
                                .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 12, y: 4)
                            
                            VStack(spacing: 8) {
                                Text("Welcome Back")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color(.label))
                                
                                Text(email)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.accent)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(AppTheme.Colors.accent.opacity(0.1))
                                    )
                            }
                        }
                    }

                    // Form section
                    VStack(spacing: 24) {
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(.label))
                            
                            ZStack {
                                if showPassword {
                                    TextField("Enter your password", text: $password)
                                        .fieldStyle()
                                } else {
                                    SecureField("Enter your password", text: $password)
                                        .fieldStyle()
                                }

                                HStack {
                                    Spacer()
                                    Button {
                                        showPassword.toggle()
                                    } label: {
                                        Image(systemName: showPassword ? "eye" : "eye.slash")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(.tertiaryLabel))
                                    }
                                    .padding(.trailing, 16)
                                }
                            }
                        }
                        
                        // Forgot password link
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                resetPassword()
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.accent)
                            .disabled(isResettingPassword)
                        }

                        // Error message
                        if let errorMessage = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                
                                Text(errorMessage)
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.red.opacity(0.1))
                            )
                        }

                        // Sign in button
                        Button {
                            signIn()
                        } label: {
                            HStack(spacing: 8) {
                                if isBusy {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Text("Sign In")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        isFormValid && !isBusy ?
                                        LinearGradient(
                                            colors: [AppTheme.Colors.accent, AppTheme.Colors.accent.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            colors: [Color(.systemGray3), Color(.systemGray4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(
                                        color: isFormValid && !isBusy ? AppTheme.Colors.accent.opacity(0.3) : .clear,
                                        radius: 8,
                                        y: 4
                                    )
                            )
                            .foregroundColor(.white)
                        }
                        .disabled(!isFormValid || isBusy)
                        .animation(.easeInOut(duration: 0.2), value: isFormValid)
                        
                        // Alternative sign in methods
                        VStack(spacing: 16) {
                            HStack {
                                Rectangle()
                                    .fill(Color(.separator).opacity(0.5))
                                    .frame(height: 1)
                                
                                Text("or")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(.tertiaryLabel))
                                    .padding(.horizontal, 16)
                                
                                Rectangle()
                                    .fill(Color(.separator).opacity(0.5))
                                    .frame(height: 1)
                            }
                            
                            Button("Try a different email") {
                                dismiss()
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(.secondaryLabel))
                        }
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarHidden(true)
        .alert("Password Reset Email Sent", isPresented: $showingResetConfirmation) {
            Button("OK") { }
        } message: {
            Text("We've sent a password reset link to \(email). Please check your email and follow the instructions to reset your password.")
        }
    }
    
    private func resetPassword() {
        isResettingPassword = true
        errorMessage = nil
        
        Task {
            do {
                try await contentModel.resetPassword(email: email)
                
                await MainActor.run {
                    isResettingPassword = false
                    showingResetConfirmation = true
                }
            } catch {
                await MainActor.run {
                    isResettingPassword = false
                    errorMessage = "Failed to send reset email. Please try again."
                }
            }
        }
    }
    
    private func signIn() {
        guard isFormValid && !isBusy else { return }
        
        isBusy = true
        errorMessage = nil
        
        Task {
            do {
                try await contentModel.signIn(email: email, password: password)
                
                await MainActor.run {
                    isBusy = false
                }
            } catch {
                await MainActor.run {
                    isBusy = false
                    errorMessage = "Invalid email or password. Please try again."
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignInView(email: "alex@example.com")
            .environment(ContentModel())
    }
}