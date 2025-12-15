//
//  GoalsDisplayView.swift
//  TimeFlow
//
//  Created by Adam Ress on 5/29/25.
//

import SwiftUI

struct GoalsDisplayView: View {
    @Environment(ContentModel.self) private var contentModel
    @Binding var selectedTab: Int
    
    @State private var editingGoal: Goal?
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var goalToDelete: Goal?
    @State private var animateContent = false
    
    private var user: User? {
        contentModel.user
    }
    
    private var activeGoals: [Goal] {
        user?.goals.filter { $0.isActive } ?? []
    }
    
    private var inactiveGoals: [Goal] {
        user?.goals.filter { !$0.isActive } ?? []
    }
    
    var body: some View {
        ZStack {
            // Professional background gradient
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
            
            VStack(spacing: 0) {
                headerSection
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Weekly Progress Overview
                        if !activeGoals.isEmpty {
                            weeklyProgressSection
                        }
                        
                        // Active Goals
                        activeGoalsSection
                        
                        // Inactive Goals (if any)
                        if !inactiveGoals.isEmpty {
                            inactiveGoalsSection
                        }
                        
                        // Quick Actions
                        quickActionsSection
                        
                        Spacer(minLength: 100) // Space for tab bar
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
                .opacity(animateContent ? 1.0 : 0)
                .offset(y: animateContent ? 0 : 20)
                .animation(.easeOut(duration: 0.8), value: animateContent)
                
                Spacer()
                
                TabBarView(selectedTab: $selectedTab)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showEditSheet) {
            GoalEditSheet(
                existing: $editingGoal,
                onSave: { saveGoal($0) },
                existingTitles: (user?.goals ?? []).map { $0.title.lowercased() }
            )
        }
        .alert("Delete Goal", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let goal = goalToDelete {
                    deleteGoal(goal)
                }
            }
        } message: {
            if let goal = goalToDelete {
                Text("Are you sure you want to delete '\(goal.title)'? This action cannot be undone.")
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
        }
    }
}

// MARK: - Header Section
private extension GoalsDisplayView {
    
    var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Goals")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(headerSubtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Button(action: addNewGoal) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(AppTheme.Colors.accent)
                                .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 4, y: 2)
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            // Subtle divider
            Rectangle()
                .fill(AppTheme.Colors.overlay.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 24)
        }
        .background(AppTheme.Colors.background)
        .opacity(animateContent ? 1.0 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.easeOut(duration: 0.6).delay(0.1), value: animateContent)
    }
    
    private var headerSubtitle: String {
        let activeCount = activeGoals.count
        if activeCount == 0 {
            return "No active goals"
        } else if activeCount == 1 {
            return "1 active goal"
        } else {
            return "\(activeCount) active goals"
        }
    }
}

// MARK: - Weekly Progress Section
private extension GoalsDisplayView {
    
    var weeklyProgressSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("This Week's Progress")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text(weekProgressSummary)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 2), spacing: 12) {
                ForEach(activeGoals) { goal in
                    WeeklyProgressCard(goal: goal)
                }
            }
        }
        .scaleEffect(animateContent ? 1.0 : 0.8)
        .opacity(animateContent ? 1.0 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateContent)
    }
    
    private var weekProgressSummary: String {
        let totalCompleted = activeGoals.reduce(0) { $0 + $1.daysCompletedThisWeek.count }
        let totalTargeted = activeGoals.reduce(0) { $0 + ($1.customPerWeek ?? 1) }
        
        return "\(totalCompleted)/\(totalTargeted) completed"
    }
}

// MARK: - Active Goals Section
private extension GoalsDisplayView {
    
    var activeGoalsSection: some View {
        VStack(spacing: 16) {
            if activeGoals.isEmpty {
                emptyGoalsView
            } else {
                VStack(spacing: 16) {
                    HStack {
                        Text("Active Goals")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Spacer()
                        
                        Text("\(activeGoals.count) goals")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    VStack(spacing: 12) {
                        ForEach(activeGoals) { goal in
                            DetailedGoalCard(
                                goal: goal,
                                onEdit: { editGoal(goal) },
                                onToggleActive: { toggleGoalActive(goal) },
                                onDelete: { requestDeleteGoal(goal) }
                            )
                        }
                    }
                }
            }
        }
        .scaleEffect(animateContent ? 1.0 : 0.8)
        .opacity(animateContent ? 1.0 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateContent)
    }
    
    var emptyGoalsView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.accent.opacity(0.1),
                                AppTheme.Colors.accent.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "target")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(AppTheme.Colors.accent)
                    )
                
                VStack(spacing: 12) {
                    Text("No Goals")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Start by adding your goals to build better habits and achieve your aspirations")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 32)
                }
                
                Button(action: addNewGoal) {
                    Text("Add Goal")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.accent, AppTheme.Colors.accent.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 8, y: 4)
                        )
                }
                .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}

// MARK: - Inactive Goals Section
private extension GoalsDisplayView {
    
    var inactiveGoalsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Paused Goals")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                Text("\(inactiveGoals.count) paused")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            VStack(spacing: 8) {
                ForEach(inactiveGoals) { goal in
                    InactiveGoalCard(
                        goal: goal,
                        onReactivate: { toggleGoalActive(goal) },
                        onDelete: { requestDeleteGoal(goal) }
                    )
                }
            }
        }
        .scaleEffect(animateContent ? 1.0 : 0.8)
        .opacity(animateContent ? 1.0 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateContent)
    }
}

// MARK: - Quick Actions Section
private extension GoalsDisplayView {
    
    var quickActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                QuickActionButton(
                    icon: "plus",
                    title: "Add New Goal",
                    subtitle: "Create a new habit or aspiration",
                    color: AppTheme.Colors.primary
                ) {
                    addNewGoal()
                }
                
                QuickActionButton(
                    icon: "chart.bar.fill",
                    title: "View Progress Analytics",
                    subtitle: "Coming soon - detailed insights",
                    color: AppTheme.Colors.secondary
                ) {
                    // TODO: Implement analytics view
                }
            }
        }
        .scaleEffect(animateContent ? 1.0 : 0.8)
        .opacity(animateContent ? 1.0 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: animateContent)
    }
}

// MARK: - Weekly Progress Card
private struct WeeklyProgressCard: View {
    let goal: Goal
    
    private var progress: Double {
        let completed = Double(goal.daysCompletedThisWeek.count)
        let target = Double(goal.customPerWeek ?? 1)
        return target > 0 ? completed / target : 0
    }
    
    private var progressText: String {
        let completed = goal.daysCompletedThisWeek.count
        let target = goal.customPerWeek ?? 1
        return "\(completed)/\(target)"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(goal.color)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: goal.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                    )
                
                Text(goal.title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                // Progress Ring
                ZStack {
                    Circle()
                        .stroke(goal.color.opacity(0.2), lineWidth: 4)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(goal.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: progress)
                    
                    Text(progressText)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                // Days indicator
                HStack(spacing: 2) {
                    ForEach(Weekday.allCases.prefix(7), id: \.self) { day in
                        Circle()
                            .fill(goal.daysCompletedThisWeek.contains(day) ? goal.color : AppTheme.Colors.textQuaternary.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.cardBackground.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(goal.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Detailed Goal Card
private struct DetailedGoalCard: View {
    let goal: Goal
    let onEdit: () -> Void
    let onToggleActive: () -> Void
    let onDelete: () -> Void
    
    @State private var showActions = false
    
    private var weeklyProgress: String {
        let completed = goal.daysCompletedThisWeek.count
        let target = goal.customPerWeek ?? 1
        return "\(completed) of \(target) this week"
    }
    
    private var totalStats: String {
        if goal.totalCompletionsAllTime > 0 {
            return "\(goal.totalCompletionsAllTime) total sessions • \(goal.totalCompletionMinutes / 60)h completed"
        } else {
            return "No sessions yet"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Icon
                Circle()
                    .fill(goal.color)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: goal.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(goal.title)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Spacer()
                        
                        // Actions button
                        Button(action: { showActions.toggle() }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(AppTheme.Colors.textPrimary.opacity(0.1))
                                )
                        }
                    }
                    
                    Text(goal.activity)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    HStack {
                        Text(weeklyProgress)
                            .font(.caption.weight(.medium))
                            .foregroundColor(goal.color)
                        
                        Spacer()
                        
                        Text("\(goal.durationMinutes) min")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
            }
            
            // Stats
            VStack(spacing: 8) {
                HStack {
                    Text("Statistics")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Spacer()
                }
                
                Text(totalStats)
                    .font(.caption2)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.cardBackground.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.overlay.opacity(0.3), lineWidth: 0.5)
                )
        )
        .confirmationDialog("Goal Actions", isPresented: $showActions, titleVisibility: .hidden) {
            Button("Edit Goal") { onEdit() }
            Button("Pause Goal") { onToggleActive() }
            Button("Delete Goal", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Inactive Goal Card
private struct InactiveGoalCard: View {
    let goal: Goal
    let onReactivate: () -> Void
    let onDelete: () -> Void
    
    @State private var showActions = false
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(AppTheme.Colors.textQuaternary.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: goal.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .strikethrough()
                
                Text("Paused")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            Spacer()
            
            Button(action: { showActions.toggle() }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(AppTheme.Colors.textPrimary.opacity(0.05))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.textPrimary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.overlay.opacity(0.2), lineWidth: 1)
                )
        )
        .confirmationDialog("Goal Actions", isPresented: $showActions, titleVisibility: .hidden) {
            Button("Reactivate Goal") { onReactivate() }
            Button("Delete Goal", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Quick Action Button
private struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(color)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.cardBackground.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.Colors.overlay.opacity(0.3), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Goal Edit Sheet
private struct GoalEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var existing: Goal?
    let onSave: (Goal) -> Void
    let existingTitles: [String]
    
    @State private var title = ""
    @State private var activity = ""
    @State private var preferences = ""
    @State private var customPerWeek = 3
    @State private var duration = 30
    @State private var selectedColor = "accent"
    @State private var selectedIcon = "target"
    @State private var showColorPicker = false
    @State private var showIconPicker = false
    @State private var showDupeAlert = false
    
    private let colors = [
        ("red", Color.red),
        ("orange", Color.orange),
        ("yellow", Color.yellow),
        ("green", Color.green),
        ("mint", Color.mint),
        ("teal", Color.teal),
        ("cyan", Color.cyan),
        ("blue", Color.blue),
        ("indigo", Color.indigo),
        ("purple", Color.purple),
        ("pink", Color.pink),
        ("accent", AppTheme.Colors.accent)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Preview
                        goalPreview
                        
                        // Form
                        VStack(spacing: 20) {
                            CleanTextField(text: $title, placeholder: "Goal title", icon: "target")
                            CleanTextField(text: $activity, placeholder: "Primary activity", icon: "figure.run")
                            
                            // Frequency and duration
                            HStack(spacing: 12) {
                                frequencyPicker
                                durationPicker
                            }
                            
                            // Preferences
                            CompactTextEditor(
                                text: $preferences,
                                placeholder: "Scheduling preferences (optional)"
                            )
                            
                            // Color and icon
                            HStack(spacing: 12) {
                                colorPicker
                                iconPicker
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle(existing == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { attemptSave() }
                        .foregroundColor(AppTheme.Colors.primary)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showColorPicker) {
            ColorPickerSheet(selectedColor: $selectedColor, colors: colors)
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerSheet(selectedIcon: $selectedIcon)
        }
        .alert("Goal Already Exists", isPresented: $showDupeAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A goal with this title already exists. Please choose a different title.")
        }
        .onAppear {
            if let goal = existing {
                populate(from: goal)
            }
        }
    }
    
    private var goalPreview: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.activityColor(selectedColor))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: selectedIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title.isEmpty ? "Goal title" : title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(activity.isEmpty ? "Primary activity" : activity)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("\(customPerWeek)× per week • \(duration) min")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.cardBackground.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.overlay, lineWidth: 1)
                )
            )
        .padding(.horizontal, 24)
    }
    
    private var frequencyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Per week")
                .font(.caption.weight(.medium))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            HStack(spacing: 8) {
                Button("-") {
                    if customPerWeek > 1 { customPerWeek -= 1 }
                }
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(AppTheme.Colors.textPrimary.opacity(0.1)))
                
                Text("\(customPerWeek)×")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(minWidth: 30)
                
                Button("+") {
                    if customPerWeek < 7 { customPerWeek += 1 }
                }
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(AppTheme.Colors.textPrimary.opacity(0.1)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.textPrimary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.overlay, lineWidth: 1)
                )
        )
    }
    
    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration")
                .font(.caption.weight(.medium))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            HStack(spacing: 8) {
                Button("-") {
                    if duration > 5 { duration = max(5, duration - 5) }
                }
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(AppTheme.Colors.textPrimary.opacity(0.1)))
                
                Text("\(duration)m")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(minWidth: 40)
                
                Button("+") {
                    if duration < 240 { duration = min(240, duration + 5) }
                }
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(AppTheme.Colors.textPrimary.opacity(0.1)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.textPrimary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.overlay, lineWidth: 1)
                )
        )
    }
    
    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.caption.weight(.medium))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Button(action: { showColorPicker = true }) {
                Circle()
                    .fill(Color.activityColor(selectedColor))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.Colors.overlay, lineWidth: 2)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.textPrimary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.overlay, lineWidth: 1)
                )
        )
    }
    
    private var iconPicker: some View {
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
                            .foregroundColor(Color.activityColor(selectedColor))
                    )
                    .overlay(
                        Circle()
                            .stroke(AppTheme.Colors.overlay, lineWidth: 2)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.textPrimary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.overlay, lineWidth: 1)
                )
        )
    }
    
    private func populate(from goal: Goal) {
        title = goal.title
        activity = goal.activity
        preferences = goal.extraPreferenceInfo
        customPerWeek = goal.customPerWeek ?? 3
        duration = goal.durationMinutes
        selectedColor = goal.colorName
        selectedIcon = goal.icon
    }
    
    private func attemptSave() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let isDuplicate = existingTitles.contains(trimmed.lowercased()) &&
                         trimmed.lowercased() != existing?.title.lowercased()
        
        if isDuplicate {
            showDupeAlert = true
            return
        }
        
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
            daysCompletedThisWeek: existing?.daysCompletedThisWeek ?? [],
            totalCompletionsAllTime: existing?.totalCompletionsAllTime ?? 0,
            totalCompletionMinutes: existing?.totalCompletionMinutes ?? 0,
            weeksActive: existing?.weeksActive ?? 0
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

// MARK: - Helper Functions
private extension GoalsDisplayView {
    
    func addNewGoal() {
        editingGoal = nil
        showEditSheet = true
    }
    
    func editGoal(_ goal: Goal) {
        editingGoal = goal
        showEditSheet = true
    }
    
    func toggleGoalActive(_ goal: Goal) {
        guard var updatedGoal = contentModel.user?.goals.first(where: { $0.id == goal.id }) else { return }
        updatedGoal.isActive.toggle()
        
        if let index = contentModel.user?.goals.firstIndex(where: { $0.id == goal.id }) {
            contentModel.user?.goals[index] = updatedGoal
            saveUserData()
        }
    }
    
    func requestDeleteGoal(_ goal: Goal) {
        goalToDelete = goal
        showDeleteAlert = true
    }
    
    func deleteGoal(_ goal: Goal) {
        contentModel.user?.goals.removeAll { $0.id == goal.id }
        saveUserData()
    }
    
    func saveGoal(_ goal: Goal) {
        if let index = contentModel.user?.goals.firstIndex(where: { $0.id == goal.id }) {
            // Update existing goal
            contentModel.user?.goals[index] = goal
        } else {
            // Add new goal
            contentModel.user?.goals.append(goal)
        }
        saveUserData()
    }
    
    func saveUserData() {
        Task {
            do {
                try await contentModel.saveUserInfo()
            } catch {
                print("Error saving goals: \(error)")
            }
        }
    }
}

#Preview {
    GoalsDisplayView(selectedTab: .constant(1))
        .environment(ContentModel())
}
