//
//  OnBoardingView.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/25/25.


import SwiftUI

struct OnBoardingView: View {
    
    @Environment(ContentModel.self) var contentModel
    @Environment(\.dismiss) private var dismiss

    @State private var user: User = User()
    @State private var currentStep: OnboardingStep = .welcome
    
    // Use consistent app theme color throughout onboarding instead of age group colors
    private let consistentThemeColor = AppTheme.Colors.primary
    // Add haptic feedback
    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        NavigationStack {
            switch currentStep {
            case .welcome:
                WelcomeView(themeColor: AppTheme.Colors.accent) {
                    currentStep = .ageGroup
                }
                
            case .ageGroup:
                SchoolLevelView { group in
                    user.ageGroup = group
                    switch group {
                    case .middleSchool, .highSchool:
                        currentStep = .schoolWorkHours
                    case .college:
                        currentStep = .collegeCourses
                    case .youngProfessional:
                        currentStep = .schoolWorkHours  // Work hours for pros
                    }
                }
            case .schoolWorkHours:
                if user.ageGroup == .youngProfessional {
                    WorkHoursView(rows: $user.workHours, themeColor: consistentThemeColor) {
                        currentStep = .awakeHours
                    }
                } else {
                    SchoolHoursView(startTime: $user.schoolHours.startTime, endTime: $user.schoolHours.endTime, themeColor: consistentThemeColor) {
                        currentStep = .awakeHours
                    }
                }
            case .collegeCourses:
                CollegeScheduleView(courses: $user.collegeCourses, themeColor: consistentThemeColor) {
                    currentStep = .awakeHours
                }
            case .awakeHours:
                ScheduleTimes(awakeHours: $user.awakeHours, themeColor: consistentThemeColor) {
                    impactFeedback.impactOccurred()
                    currentStep = .goals
                }
            case .goals:
                GoalsView(goals: $user.goals, themeColor: consistentThemeColor) {
                    impactFeedback.impactOccurred()
                    currentStep = .recurringCommitments
                }
            case .recurringCommitments:
                RecurringCommitmentsView(commitments: $user.recurringCommitments, themeColor: consistentThemeColor) {
                    impactFeedback.impactOccurred()
                    if user.ageGroup == .youngProfessional {
                        currentStep = .notifications
                    } else {
                        currentStep = .assignmentsTests
                    }
                }
            case .assignmentsTests:
                UpcomingWorkView(assignments: $user.assignments, tests: $user.tests, classes: $user.classes, themeColor: consistentThemeColor) {
                    impactFeedback.impactOccurred()
                    currentStep = .notifications
                }
            case .notifications:
                NotificationsWidgetsView(themeColor: consistentThemeColor) {  // Assuming this view exists
                    impactFeedback.impactOccurred()
                    currentStep = .subscription
                }
            case .subscription:
                SubscriptionView(onContinue: {
                    Task {
                        await finishOnboarding()
                    }
                })
            case .complete:
                Text("Onboarding Complete!")  // Placeholder
            }
        }
        .ignoresSafeArea()
    }
    
    @MainActor
    private func finishOnboarding() async {
        if contentModel.currentUID() != nil {
            contentModel.user = user
            do {
                try await contentModel.saveUserInfo()
                contentModel.newUser = false
                try await contentModel.onboardingComplete()
                dismiss()
            } catch {
                print("Error saving onboarding: \(error)")
            }
        } else {
            print("Error getting user ID")
        }
    }
}

#Preview {
    OnBoardingView()
        .environment(ContentModel())
}