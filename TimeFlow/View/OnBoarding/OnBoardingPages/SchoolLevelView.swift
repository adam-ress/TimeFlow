//
//  SchoolLevel.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/27/25.
//

import SwiftUI
import UIKit

struct SchoolLevelView: View {
    var onContinue: (AgeGroup) -> Void = { _ in }
    
    @State private var selection: AgeGroup?
    
    private let grid = [GridItem(.adaptive(minimum: 150), spacing: 16)]
    
    private let cardFill = AppTheme.Colors.cardBackground
    private let cardStroke = AppTheme.Colors.cardStroke
    
    // Use consistent app theme color instead of age group theme color
    private let consistentThemeColor = AppTheme.Colors.primary
    
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            //background
            LinearGradient(
                colors: [
                    AppTheme.Colors.background,
                    AppTheme.Colors.secondary.opacity(0.3),
                    AppTheme.Colors.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 36) {
                header
                LazyVGrid(columns: grid, spacing: 18) {
                    ForEach(AgeGroup.allCases) { card(for: $0) }
                }
                .padding(.horizontal)
                .scaleEffect(animateContent ? 1.0 : 0.8)
                .opacity(animateContent ? 1.0 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
                Spacer()
                continueButton
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { progressToolbar }
        .onAppear {
            withAnimation {
                animateContent = true
            }
        }
    }
    
    @ToolbarContentBuilder
    var progressToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Text("Step 1 of 8")  // Adjust
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    var header: some View {
        VStack(spacing: 10) {
            Text("Tell us where you are")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            Text("We'll tailor the planner around your day-to-day reality.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal)
        }
        .padding(.top, 60)
        .opacity(animateContent ? 1.0 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.easeOut(duration: 0.8), value: animateContent)
    }
    
    func card(for group: AgeGroup) -> some View {
        let picked = selection == group
        return VStack(spacing: 14) {
            Image(systemName: group.icon)
                .font(.system(size: 42, weight: .semibold))
                .foregroundColor(picked ? consistentThemeColor : AppTheme.Colors.textPrimary)
            Text(group.rawValue)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, minHeight: 150)
        .themeCardWithStroke(selected: picked, strokeColor: consistentThemeColor)
        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
        .onTapGesture {
            withAnimation(.easeInOut) {
                selection = group
            }
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(picked ? .isSelected : [])
    }
    
    var continueButton: some View {
        Button {
            if let s = selection {
                // Add haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                onContinue(s)
            }
        } label: {
            Text("Continue")
                .fontWeight(.semibold)
        }
        .themeButton(enabled: selection != nil, color: consistentThemeColor)
        .disabled(selection == nil)
        .padding(.horizontal)
        .padding(.bottom, 22)
    }
}

#Preview {
    NavigationStack { SchoolLevelView() }
}
