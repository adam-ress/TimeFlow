//
//  Notifications&Widgets.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/28/25.
//

import SwiftUI
import UserNotifications

struct NotificationsWidgetsView: View {
    
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false
    
    let themeColor: Color
    var onContinue: () -> Void = {}
    
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            // Clean gradient background
            LinearGradient(
                colors: [
                    AppTheme.Colors.background,
                    AppTheme.Colors.secondary.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    header
                    notificationCard
                    Spacer(minLength: 60)
                    actionButtons
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 40)
            }
        }
        .task {
            permissionStatus = await currentStatus()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
        }
    }
}

// MARK: - Sub-views
private extension NotificationsWidgetsView {
    
    var header: some View {
        VStack(spacing: 16) {
            Text("Stay Focused")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            Text("Get timely reminders to keep your schedule on track")
                .font(.system(size: 17, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineLimit(2)
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : -30)
        .animation(.easeOut(duration: 0.8), value: animateContent)
    }
    
    var notificationCard: some View {
        VStack(spacing: 32) {
            // Icon
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "bell.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(themeColor)
            }
            
            // Content
            VStack(spacing: 16) {
                Text("Smart Notifications")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Receive gentle reminders before events start and helpful suggestions when your schedule gets busy.")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineSpacing(2)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(AppTheme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(AppTheme.Colors.separator, lineWidth: 1)
                )
        )
        .scaleEffect(animateContent ? 1 : 0.9)
        .opacity(animateContent ? 1 : 0)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: animateContent)
    }
    
    var actionButtons: some View {
        VStack(spacing: 16) {
            // Primary action button
            Button {
                Task {
                    await requestPermission()
                }
            } label: {
                HStack(spacing: 12) {
                    if isRequesting {
                        ProgressView()
                            .scaleEffect(0.9)
                            .tint(.white)
                    } else {
                        if permissionStatus == .authorized {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        
                        Text(buttonTitle)
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(buttonBackgroundColor)
            )
            .foregroundColor(.white)
            .disabled(isRequesting || permissionStatus == .authorized)
            .opacity(isRequesting ? 0.7 : 1)
            
            // Secondary action button
            Button(action: onContinue) {
                Text(skipButtonTitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(.top, 8)
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.easeOut(duration: 0.6).delay(0.4), value: animateContent)
    }
    
    // MARK: - Computed Properties
    
    private var buttonTitle: String {
        switch permissionStatus {
        case .authorized: 
            return "Notifications Enabled"
        case .denied: 
            return "Open Settings"
        default: 
            return "Enable Notifications"
        }
    }
    
    private var skipButtonTitle: String {
        permissionStatus == .authorized ? "Continue" : "Maybe Later"
    }
    
    private var buttonBackgroundColor: Color {
        switch permissionStatus {
        case .authorized: 
            return .green
        case .denied: 
            return .orange
        default: 
            return themeColor
        }
    }
}

// MARK: - Permission Helpers
private extension NotificationsWidgetsView {
    
    func currentStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
    
    @MainActor
    func requestPermission() async {
        guard permissionStatus != .authorized else { 
            onContinue()
            return 
        }
        
        if permissionStatus == .denied {
            // Open Settings
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(settingsUrl)
            }
            
            // Check status again after user returns
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                Task {
                    permissionStatus = await currentStatus()
                    if permissionStatus == .authorized {
                        await MainActor.run {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                onContinue()
                            }
                        }
                    }
                }
            }
            return
        }
        
        isRequesting = true
        
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            
            permissionStatus = granted ? .authorized : .denied
            
            if granted {
                // Small delay for better UX, then continue
                try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
                onContinue()
            }
            
        } catch {
            print("Error requesting notification permission: \(error)")
            permissionStatus = .denied
        }
        
        isRequesting = false
    }
}