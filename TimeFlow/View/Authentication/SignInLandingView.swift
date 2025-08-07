//
//  SignInLandingView.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/14/25.
//

//  SignInLandingView.swift
import SwiftUI
import AuthenticationServices

struct SignInLandingView: View {
    
    @Environment(ContentModel.self) private var contentModel
    
    @State private var showEmailSheet = false

    var body: some View {
        ZStack {
            // Updated background gradient to match app theme and adapt to color scheme
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

            VStack(spacing: 0) {
                // Top spacing
                Spacer()
                    .frame(minHeight: 60)

                // Hero section
                VStack(spacing: 32) {
                    // App icon/logo area
                    VStack(spacing: 24) {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 20, y: 8)
                        
                        VStack(spacing: 16) {
                            Text("TimeFlow")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(Color(.label))
                                .tracking(-1)
                            
                            Text("AI-powered scheduling for your perfect day")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(.secondaryLabel))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .padding(.horizontal, 24)
                        }
                    }
                }

                // Flexible spacing that adapts to screen size
                Spacer()
                    .frame(minHeight: 80, maxHeight: 120)

                // Authentication buttons section
                VStack(spacing: 0) {
                    VStack(spacing: 14) {
                        // Apple Sign-In
                        Button {
                            Task {
                                // TODO: Implement Apple Sign-In
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Continue with Apple")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.black)
                            )
                            .foregroundColor(.white)
                        }

                        // Google Sign-In
                        GoogleButton()

                        // Email Sign-In
                        Button {
                            showEmailSheet = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Continue with Email")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.secondarySystemBackground))
                                    .shadow(color: Color(.black).opacity(0.06), radius: 12, y: 6)
                            )
                            .foregroundColor(Color(.label))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 28)
                    
                    Spacer()
                    
                    // Terms and privacy
                    VStack(spacing: 8) {
                        Text("By continuing, you agree to our")
                            .font(.system(size: 13))
                            .foregroundColor(Color(.tertiaryLabel))
                        
                        HStack(spacing: 4) {
                            Button("Terms of Service") {
                                // TODO: Open terms
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.accent)
                            
                            Text("and")
                                .font(.system(size: 13))
                                .foregroundColor(Color(.tertiaryLabel))
                            
                            Button("Privacy Policy") {
                                // TODO: Open privacy policy
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.accent)
                        }
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 44)
                }
            }
        }
        .sheet(isPresented: $showEmailSheet) {
            NavigationStack {
                EmailEntryView()
            }
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    SignInLandingView()
        .environment(ContentModel())
}


// Updated Google Button to match theme
struct GoogleButton: View {
    @Environment(\.openURL) private var openURL
    @Environment(ContentModel.self) private var contentModel
    @Environment(\.scenePhase) private var phase
    
    @State private var busy = false
    
    var body: some View {
        Button {
            Task {
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                
                busy = true
                
                do {
                    try await contentModel.googleSignIn(windowScene: scene)
                } catch {
                    print(error.localizedDescription)
                }
                
                busy = false
                
                contentModel.checkLogin()
            }
        } label: {
            HStack(spacing: 12) {
                if busy {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Color(.secondaryLabel))
                } else {
                    Image("google_icon")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                
                Text(busy ? "Signing in..." : "Continue with Google")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white)
                    .shadow(color: Color(.black).opacity(0.08), radius: 12, y: 6)
            )
            .foregroundColor(.black)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.separator).opacity(0.15), lineWidth: 1)
            )
        }
        .disabled(busy)
    }
}
