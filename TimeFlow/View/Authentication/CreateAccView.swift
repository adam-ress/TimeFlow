//
//  CreateAccountView.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/19/25.
//

import SwiftUI

struct CreateAccView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(ContentModel.self) private var contentModel
    
    let email: String

    // Local UI state
    @State private var fullName = ""
    @State private var password = ""
    @State private var isBusy = false
    @State private var errorMessage: String?
    
    @State private var age = 18
    @State private var showAgeSel = false
    
    @State private var showPassword = false

    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        password.count >= 6 &&
        age >= 13
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
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundColor(.white)
                                )
                                .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 12, y: 4)
                            
                            VStack(spacing: 8) {
                                Text("Create Your Account")
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
                        // Full name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Name")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(.label))
                            
                            TextField("Enter your full name", text: $fullName)
                                .fieldStyle()
                        }
                        
                        // Age selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Age")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(.label))
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showAgeSel.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("\(age) years old")
                                        .foregroundColor(Color(.label))
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .medium))
                                        .rotationEffect(.degrees(showAgeSel ? 180 : 0))
                                        .foregroundColor(Color(.tertiaryLabel))
                                        .animation(.easeInOut(duration: 0.25), value: showAgeSel)
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                        .shadow(color: Color(.black).opacity(0.03), radius: 4, y: 2)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            if showAgeSel {
                                Picker("Age", selection: $age) {
                                    ForEach(13...100, id: \.self) { ageValue in
                                        Text("\(ageValue) years old")
                                            .foregroundColor(Color(.label))
                                            .tag(ageValue)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 120)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                        .shadow(color: Color(.black).opacity(0.03), radius: 4, y: 2)
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(.label))
                            
                            ZStack {
                                if showPassword {
                                    TextField("Create a secure password", text: $password)
                                        .fieldStyle()
                                } else {
                                    SecureField("Create a secure password", text: $password)
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
                            
                            if !password.isEmpty && password.count < 6 {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                    
                                    Text("Password must be at least 6 characters")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 4)
                            }
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

                        // Create account button
                        Button {
                            createAccount()
                        } label: {
                            HStack(spacing: 8) {
                                if isBusy {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Text("Create Account")
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
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarHidden(true)
    }
    
    private func createAccount() {
        guard isFormValid && !isBusy else { return }
        
        isBusy = true
        errorMessage = nil
        
        Task {
            do {
                try await contentModel.createAccount(
                    email: email,
                    name: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                
                await MainActor.run {
                    contentModel.checkLogin()
                    isBusy = false
                }
            } catch {
                await MainActor.run {
                    isBusy = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - TextField style helper
extension View {
    func fieldStyle() -> some View {
        self
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(.system(size: 16))
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color(.black).opacity(0.03), radius: 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
            )
            .foregroundColor(Color(.label))
    }
}

// PREVIEW ------------------------------------------------------------
#Preview {
    NavigationStack {
        CreateAccView(email: "alex@example.com")
            .environment(ContentModel())
    }
}