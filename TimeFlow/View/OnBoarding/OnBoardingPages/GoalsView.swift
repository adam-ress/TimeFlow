//
//  GoalsView.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/28/25.
//

import SwiftUI

struct GoalsView: View {
    
    @Binding var goals: [Goal]
    let themeColor: Color
    @State private var editingGoal: Goal?
    @State private var showSheet = false
    @State private var editMode: EditMode = .inactive
    
    
    private let card = AppTheme.Colors.cardBackground
    
    // Recommended goals based on common activities
    private let recommendedGoals = [
        Goal(title: "Exercise", activity: "Gym workout", extraPreferenceInfo: "", cadence: .thriceWeekly, durationMinutes: 45, colorName: "green", icon: "figure.run", daysCompletedThisWeek: []),
        Goal(title: "Reading", activity: "Read books", extraPreferenceInfo: "I prefer to read right before bed", cadence: .daily, durationMinutes: 30, colorName: "blue", icon: "book.fill", daysCompletedThisWeek: []),
        Goal(title: "Meditation", activity: "Mindfulness practice", extraPreferenceInfo: "", cadence: .daily, durationMinutes: 15, colorName: "purple", icon: "leaf.fill", daysCompletedThisWeek: []),
        Goal(title: "Learn Language", activity: "Language practice", extraPreferenceInfo: "", cadence: .daily, durationMinutes: 20, colorName: "orange", icon: "globe", daysCompletedThisWeek: []),
        Goal(title: "Creative Writing", activity: "Writing practice", extraPreferenceInfo: "", cadence: .thriceWeekly, durationMinutes: 30, colorName: "pink", icon: "pencil", daysCompletedThisWeek: []),
        Goal(title: "Cooking", activity: "Learn new recipes", extraPreferenceInfo: "", cadence: .thriceWeekly, durationMinutes: 60, colorName: "red", icon: "fork.knife", daysCompletedThisWeek: [])
    ]
    
    var onContinue: () -> Void = {}
    
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
            
            VStack(spacing: 26) {
                header
                goalList
                quickAddSection
                addButton
                Spacer(minLength: 12)
                continueButton
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { progressToolbar(currentStep: 4) {
            onContinue()
        } }
        .sheet(isPresented: $showSheet) {
            AddEditGoalSheet(
                existing: $editingGoal,
                onSave: { saveGoal($0) },
                existingTitles: goals.map { $0.title.lowercased() },
                themeColor: themeColor
            )
        }
        .environment(\.editMode, $editMode)
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation {
                animateContent = true
            }
        }
    }
}

// MARK: - Header, list, CTA
private extension GoalsView {
    
    var header: some View {
        VStack(spacing: 8) {
            Text("Tell us what you're working toward.")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text("We'll carve out time for each goal automatically.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(.top, 12)
        .opacity(animateContent ? 1.0 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.easeOut(duration: 0.8), value: animateContent)
    }
    
    var goalList: some View {
        Group {
            if goals.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "target")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    Text("No goals yet")
                        .font(.headline)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    Text("Add your first goal below or pick from suggestions")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textQuaternary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .themeCard()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(goals) { goal in
                                GoalRowOnboarding(goal: goal) {
                                    edit(goal)
                                } onDelete: {
                                    deleteGoalWithAnimation(goal)
                                }
                                .id(goal.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .top)),
                                    removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .leading))
                                ))
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxHeight: 280)
                    .onChange(of: goals.count) { oldCount, newCount in
                        // Scroll to bottom when new goal is added
                        if newCount > oldCount && newCount > 0 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeOut(duration: 0.8)) {
                                    proxy.scrollTo(goals.last?.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
        }
        .scaleEffect(animateContent ? 1.0 : 0.8)
        .opacity(animateContent ? 1.0 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
    }
    
    var addButton: some View {
        Button {
            editingGoal = nil
            showSheet = true
        } label: {
            Label("Add custom goal", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.clear)
                .foregroundColor(themeColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(themeColor, lineWidth: 2)
                )
                .cornerRadius(14)
        }
        .scaleEffect(animateContent ? 1.0 : 0.8)
        .opacity(animateContent ? 1.0 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
    }
    
    var quickAddSection: some View {
        Group {
            if goals.isEmpty && !recommendedGoals.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Popular goals")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .padding(.horizontal, 4)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recommendedGoals.prefix(4)) { recommendedGoal in
                                CompactRecommendedGoalCard(goal: recommendedGoal) {
                                    addRecommendedGoal(recommendedGoal)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .opacity(animateContent ? 1.0 : 0)
                .scaleEffect(animateContent ? 1.0 : 0.9)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateContent)
            }
        }
    }
    
    var continueButton: some View {
        Button(action: onContinue) {
            Text("Continue")
                .fontWeight(.semibold)
        }
        .themeButton(enabled: !goals.isEmpty, color: themeColor)
        .disabled(goals.isEmpty)
    }
}

// MARK: - Goal row
private struct GoalRowOnboarding: View {
    let goal: Goal
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Circle()
                    .fill(goalColor)
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: goal.icon).foregroundColor(.white))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title).fontWeight(.semibold).foregroundColor(AppTheme.Colors.textPrimary)
                    Text(goal.activity).font(.caption).foregroundColor(AppTheme.Colors.textTertiary)
                    Text(subtitle).font(.caption2).foregroundColor(AppTheme.Colors.textQuaternary)
                }
                
                Spacer()
                
                // Menu button for delete
                Button(action: { showDeleteAlert = true }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(AppTheme.Colors.textPrimary.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .themeCard()
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isDeleting ? 0.95 : 1.0)
        .opacity(isDeleting ? 0.7 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDeleting)
        .alert("Delete Goal", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                isDeleting = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onDelete()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(goal.title)'?")
        }
    }
    
    private var goalColor: Color {
        return Color.activityColor(goal.colorName)
    }
    
    private var subtitle: String {
        let freq = goal.cadence == .custom ? "\(goal.customPerWeek ?? 0)×/wk"
                                           : goal.cadence.rawValue
        return "\(freq) • \(goal.durationMinutes) min"
    }
}

// MARK: - Compact Recommended Goal Card
private struct CompactRecommendedGoalCard: View {
    let goal: Goal
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Circle()
                    .fill(goalColor)
                    .frame(width: 20, height: 20)
                    .overlay(Image(systemName: goal.icon).font(.system(size: 10)).foregroundColor(.white))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(goal.title)
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Text("\(goal.durationMinutes)m")
                        .font(.caption2)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(goalColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.textPrimary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.Colors.overlay, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var goalColor: Color {
        return Color.activityColor(goal.colorName)
    }
}

// MARK: - Recommended Goal Card
private struct RecommendedGoalCard: View {
    let goal: Goal
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Circle()
                    .fill(goalColor)
                    .frame(width: 24, height: 24)
                    .overlay(Image(systemName: goal.icon).font(.system(size: 12)).foregroundColor(.white))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(AppTheme.Colors.textQuaternary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(goalColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(goalColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var goalColor: Color {
        return Color.activityColor(goal.colorName)
    }
    
    private var subtitle: String {
        let freq = goal.cadence == .custom ? "\(goal.customPerWeek ?? 0)×/wk"
                                           : goal.cadence.rawValue
        return "\(freq) • \(goal.durationMinutes) min"
    }
}

// ----------------------------------------------------------------------
//  PROFESSIONAL ADD / EDIT SHEET
// ----------------------------------------------------------------------
private struct AddEditGoalSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @Binding var existing: Goal?
    let onSave: (Goal) -> Void
    let existingTitles: [String]
    let themeColor: Color
    
    @State private var title = ""
    @State private var activity = ""
    @State private var preferences = ""
    @State private var cadence: Cadence = .custom
    @State private var customPerWeek = 3
    @State private var duration = 30
    @State private var selectedColor = "accent"
    @State private var selectedIcon = "target"
    @State private var showAdvanced = false
    
    // Keep track of the original tracking data that shouldn't be edited
    @State private var daysCompletedThisWeek: [Weekday] = []
    @State private var totalCompletionsAllTime = 0
    @State private var totalCompletionMinutes = 0
    @State private var weeksActive = 0
    
    @State private var showDupeAlert = false
    @State private var showColorPicker = false
    @State private var showIconPicker = false
    
    // Use consistent app theme color for main buttons instead of age group color
    private let consistentThemeColor = AppTheme.Colors.primary
    
    private let colors = [
        ("red", AppTheme.ActivityColors.red),
        ("orange", AppTheme.ActivityColors.orange),
        ("yellow", AppTheme.ActivityColors.yellow),
        ("green", AppTheme.ActivityColors.green),
        ("mint", AppTheme.ActivityColors.mint),
        ("teal", AppTheme.ActivityColors.teal),
        ("cyan", AppTheme.ActivityColors.cyan),
        ("blue", AppTheme.ActivityColors.blue),
        ("indigo", AppTheme.ActivityColors.indigo),
        ("purple", AppTheme.ActivityColors.purple),
        ("pink", AppTheme.ActivityColors.pink),
        ("accent", AppTheme.Colors.accent)
    ]

    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            mainContent
                                .padding(.horizontal, 24)
                                .padding(.top, 24)
                            
                            // Advanced options toggle
                            VStack(spacing: 16) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showAdvanced.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Text("Preferences & appearance")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(AppTheme.Colors.textTertiary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(AppTheme.Colors.textTertiary)
                                            .rotationEffect(.degrees(showAdvanced ? 180 : 0))
                                    }
                                    .padding(.horizontal, 24)
                                }
                                
                                if showAdvanced {
                                    VStack(spacing: 16) {
                                        advancedOptions
                                    }
                                    .padding(.horizontal, 24)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            
                            Spacer(minLength: 80)
                        }
                        .padding(.bottom, 20)
                    }
                    
                    // Save button
                    saveButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                        .background(AppTheme.Colors.background)
                }
            }
            .navigationBarHidden(true)
            .alert("Goal Already Exists", isPresented: $showDupeAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("A goal with this title already exists. Please choose a different title.")
            }
            .sheet(isPresented: $showColorPicker) {
                ColorPickerSheet(selectedColor: $selectedColor, colors: colors)
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerSheet(selectedIcon: $selectedIcon)
            }
            .onAppear {
                cadence = .custom
                if let g = existing {
                    populate(from: g)
                    // Show advanced if non-default preferences or appearance
                    showAdvanced = !g.extraPreferenceInfo.isEmpty || g.colorName != "accent" || g.icon != "target"
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(AppTheme.Colors.textPrimary.opacity(0.7))
                
                Spacer()
                
                Text(existing == nil ? "New Goal" : "Edit Goal")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .opacity(0)
                .disabled(true)
            }
            
            // Simple preview
            HStack(spacing: 12) {
                Circle()
                    .fill(currentColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: selectedIcon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.isEmpty ? "Goal title" : title)
                        .font(.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(activity.isEmpty ? "Primary activity" : activity)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text(simpleScheduleText)
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textQuaternary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.textPrimary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.Colors.overlay, lineWidth: 1)
                    )
            )
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 20) {
            // Title and activity
            CleanTextField(
                text: $title,
                placeholder: "Goal title",
                icon: "target"
            )
            
            CleanTextField(
                text: $activity,
                placeholder: "Primary activity",
                icon: "figure.run"
            )
            
            // Frequency and duration in one row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Per week")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    HStack(spacing: 8) {
                        Button("-") {
                            if customPerWeek > 1 {
                                customPerWeek -= 1
                            }
                        }
                        .foregroundColor(consistentThemeColor)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(AppTheme.Colors.textPrimary.opacity(0.1)))
                        
                        Text("\(customPerWeek)×")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(minWidth: 30)
                        
                        Button("+") {
                            if customPerWeek < 7 {
                                customPerWeek += 1
                            }
                        }
                        .foregroundColor(consistentThemeColor)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(AppTheme.Colors.textPrimary.opacity(0.1)))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.textPrimary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.Colors.overlay, lineWidth: 1)
                        )
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Duration")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    HStack(spacing: 8) {
                        Button("-") {
                            if duration > 5 {
                                duration = max(5, duration - 5)
                            }
                        }
                        .foregroundColor(consistentThemeColor)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(AppTheme.Colors.textPrimary.opacity(0.1)))
                        
                        Text("\(duration)m")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(minWidth: 35)
                        
                        Button("+") {
                            if duration < 240 {
                                duration = min(240, duration + 5)
                            }
                        }
                        .foregroundColor(consistentThemeColor)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(AppTheme.Colors.textPrimary.opacity(0.1)))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.textPrimary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.Colors.overlay, lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var advancedOptions: some View {
        VStack(spacing: 16) {
            // Preferences
            CompactTextEditor(
                text: $preferences,
                placeholder: "Scheduling preferences (e.g., 'prefer mornings', 'not after school')"
            )
            
            // Color and icon selection - compact
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Button(action: { showColorPicker = true }) {
                        Circle()
                            .fill(currentColor)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.Colors.overlay, lineWidth: 2)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.textPrimary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.Colors.overlay, lineWidth: 1)
                        )
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Button(action: { showIconPicker = true }) {
                        Circle()
                            .fill(AppTheme.Colors.textPrimary.opacity(0.1))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(currentColor)
                            )
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.Colors.overlay, lineWidth: 2)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.textPrimary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.Colors.overlay, lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var saveButton: some View {
        Button(action: attemptSave) {
            Text(existing == nil ? "Create Goal" : "Save Changes")
                .font(.headline.weight(.semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(consistentThemeColor)
                        .shadow(color: consistentThemeColor.opacity(0.3), radius: 4, y: 2)
                )
        }
        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1.0)
    }
    
    private var currentColor: Color {
        return Color.activityColor(selectedColor)
    }
    
    private var simpleScheduleText: String {
        let freq = customPerWeek == 1 ? "1× per week" : 
                   customPerWeek == 7 ? "Daily" : 
                   "\(customPerWeek)× per week"
        return "\(freq) • \(duration) min"
    }
    
    private var cadenceText: String {
        return "\(customPerWeek)× per week • \(duration) min"
    }
    
    private func populate(from g: Goal) {
        title = g.title
        activity = g.activity
        preferences = g.extraPreferenceInfo
        cadence = .custom
        customPerWeek = g.customPerWeek ?? 3
        duration = g.durationMinutes
        selectedColor = g.colorName
        selectedIcon = g.icon
        
        // Preserve the tracking data
        daysCompletedThisWeek = g.daysCompletedThisWeek
        totalCompletionsAllTime = g.totalCompletionsAllTime
        totalCompletionMinutes = g.totalCompletionMinutes
        weeksActive = g.weeksActive
    }
    
    private func attemptSave() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let dup = existingTitles.contains(trimmed.lowercased()) &&
                  trimmed.lowercased() != existing?.title.lowercased()
        if dup { showDupeAlert = true; return }
        
        let goalId = existing?.id ?? UUID()
        
        let goal = Goal(
            isActive: existing?.isActive ?? true,
            id: goalId,
            title: trimmed,
            activity: activity,
            extraPreferenceInfo: preferences,
            cadence: .custom,
            customPerWeek: customPerWeek,
            durationMinutes: duration,
            colorName: selectedColor,
            icon: selectedIcon,
            daysCompletedThisWeek: daysCompletedThisWeek,
            totalCompletionsAllTime: totalCompletionsAllTime,
            totalCompletionMinutes: totalCompletionMinutes,
            weeksActive: weeksActive
        )
        
        onSave(goal)
        dismiss()
    }
}

// MARK: - Helper Components
private struct CleanTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.Colors.textTertiary)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .font(.body)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.textPrimary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.overlay, lineWidth: 1)
                )
        )
    }
}

private struct CompactTextEditor: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.textPrimary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.overlay, lineWidth: 1)
                )
                .frame(height: 80)
            
            if text.isEmpty {
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textQuaternary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
            
            TextEditor(text: $text)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
    }
}

// MARK: - CRUD helpers
private extension GoalsView {
    func saveGoal(_ g: Goal) {
        if let i = goals.firstIndex(where: { $0.id == g.id }) {
            goals[i] = g  // Update existing goal
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                goals.append(g)
            }
        }
    }
    
    func deleteGoal(_ g: Goal) { 
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            goals.removeAll { $0.id == g.id }
        }
    }
    
    func deleteGoalWithAnimation(_ g: Goal) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            goals.removeAll { $0.id == g.id }
        }
    }
    
    func moveGoal(from src: IndexSet, to dest: Int) { goals.move(fromOffsets: src, toOffset: dest) }
    func edit(_ g: Goal) { editingGoal = g; showSheet = true }
    
    func addRecommendedGoal(_ recommendedGoal: Goal) {
        let newGoal = Goal(
            isActive: true,
            id: UUID(),
            title: recommendedGoal.title,
            activity: recommendedGoal.activity,
            extraPreferenceInfo: recommendedGoal.extraPreferenceInfo,
            cadence: recommendedGoal.cadence,
            customPerWeek: recommendedGoal.customPerWeek,
            durationMinutes: recommendedGoal.durationMinutes,
            colorName: recommendedGoal.colorName,
            icon: recommendedGoal.icon,
            daysCompletedThisWeek: [],
            totalCompletionsAllTime: 0,
            totalCompletionMinutes: 0,
            weeksActive: 0
        )
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            goals.append(newGoal)
        }
    }
}