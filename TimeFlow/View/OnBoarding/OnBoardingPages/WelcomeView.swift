//
//  WelcomeView.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/28/25.
//

import SwiftUI

struct WelcomeView: View {
    
    let themeColor: Color
    var onContinue: () -> Void = {}
    
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            // Background gradient
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
                Spacer()
                
                // Main content
                VStack(spacing: 40) {
                    // Welcome message
                    VStack(spacing: 16) {
                        Text("Welcome to TimeFlow")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(.label))
                            .multilineTextAlignment(.center)
                        
                        Text("Let's set up your personalized schedule in just a few quick steps")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color(.secondaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // Simple feature list
                    VStack(spacing: 16) {
                        featureRow(icon: "brain", title: "AI-powered scheduling")
                        featureRow(icon: "target", title: "Goal tracking and planning")
                        featureRow(icon: "calendar", title: "Flexible daily organization")
                    }
                    .padding(.horizontal, 32)
                }
                .scaleEffect(animateContent ? 1.0 : 0.95)
                .opacity(animateContent ? 1.0 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: animateContent)
                
                Spacer()
                Spacer()
                
                // Bottom section
                VStack(spacing: 20) {
                    Button(action: onContinue) {
                        HStack(spacing: 8) {
                            Text("Get Started")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [themeColor, themeColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: themeColor.opacity(0.3), radius: 8, y: 4)
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(PressableButtonStyle())
                    
                    Text("Takes about 2 minutes")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 44)
                .opacity(animateContent ? 1.0 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.3), value: animateContent)
            }
        }
        .onAppear {
            withAnimation {
                animateContent = true
            }
        }
    }
}

// MARK: - Components
private extension WelcomeView {
    
    func featureRow(icon: String, title: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(themeColor)
                .frame(width: 24, height: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(.label))
            
            Spacer()
        }
    }
}

// MARK: - Custom Button Style
private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    WelcomeView(themeColor: AppTheme.Colors.accent)
}