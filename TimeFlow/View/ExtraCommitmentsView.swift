//
//  ExtraCommitmentsView.swift
//  TimeFlow
//
//  Created by Adam Ress on 7/14/25.
//

import SwiftUI

struct ExtraCommitmentsView: View {
    
    @Environment(ContentModel.self) var contentModel
    
    @State private var user: User = User() 
    @State private var showingAddSheet = false
    @State private var editingCommitment: RecurringCommitment?
    @State private var animateContent = false
    @State private var showDeleteAlert = false
    @State private var commitmentToDelete: RecurringCommitment?
    
    @Binding var selectedTab: Int
    
    var body: some View {
        ZStack {
            // Background gradient
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
                
                if user.recurringCommitments.isEmpty {
                    emptyStateView
                } else {
                    commitmentListView
                }
                
                Spacer()
                
                TabBarView(selectedTab: $selectedTab)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let currentUser = contentModel.user {
                user = currentUser
            }
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            CommitmentEditSheet(
                commitment: $editingCommitment,
                onSave: saveCommitment
            )
        }
        .sheet(item: $editingCommitment) { commitment in
            CommitmentEditSheet(
                commitment: $editingCommitment,
                onSave: saveCommitment
            )
        }
        .alert("Delete Commitment", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let commitment = commitmentToDelete {
                    deleteCommitment(commitment)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(commitmentToDelete?.title ?? "")'?")
        }
    }
}

// MARK: - Header Section
private extension ExtraCommitmentsView {
    
    var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Commitments")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(headerSubtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    editingCommitment = nil
                    showingAddSheet = true
                }) {
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
        let count = user.recurringCommitments.count
        if count == 0 {
            return "No commitments yet"
        } else if count == 1 {
            return "1 commitment"
        } else {
            return "\(count) commitments"
        }
    }
}

// MARK: - Empty State View
private extension ExtraCommitmentsView {
    
    var emptyStateView: some View {
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
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(AppTheme.Colors.accent)
                    )
                
                VStack(spacing: 12) {
                    Text("No Commitments")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Add your regular weekly activities like gym sessions, music lessons, or volunteer work")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 32)
                }
                
                Button(action: {
                    editingCommitment = nil
                    showingAddSheet = true
                }) {
                    Text("Add Commitment")
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
        .opacity(animateContent ? 1.0 : 0)
        .scaleEffect(animateContent ? 1.0 : 0.9)
        .animation(.easeOut(duration: 0.8).delay(0.2), value: animateContent)
    }
}

// MARK: - Commitment List View
private extension ExtraCommitmentsView {
    
    var commitmentListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(user.recurringCommitments.enumerated()), id: \.offset) { index, commitment in
                    CommitmentCard(
                        commitment: commitment,
                        onEdit: { editingCommitment = commitment },
                        onDelete: {
                            commitmentToDelete = commitment
                            showDeleteAlert = true
                        }
                    )
                    .opacity(animateContent ? 1.0 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2 + Double(index) * 0.1), value: animateContent)
                }
                
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 100)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }
}

// MARK: - Helper Functions
private extension ExtraCommitmentsView {
    
    func saveCommitment(_ commitment: RecurringCommitment) {
        if let index = user.recurringCommitments.firstIndex(where: { $0.id == commitment.id }) {
            user.recurringCommitments[index] = commitment
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                user.recurringCommitments.append(commitment)
            }
        }
        contentModel.user = user
        Task {
            try? await contentModel.saveUserInfo()
        }
    }
    
    func deleteCommitment(_ commitment: RecurringCommitment) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            user.recurringCommitments.removeAll { $0.id == commitment.id }
        }
        contentModel.user = user
        Task {
            try? await contentModel.saveUserInfo()
        }
        commitmentToDelete = nil
    }
}

// MARK: - Supporting Views

private struct CommitmentCard: View {
    let commitment: RecurringCommitment
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingOptions = false
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(commitment.color.opacity(0.2))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: commitment.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(commitment.color)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(commitment.title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(frequencyText)
                        .font(.caption.weight(.medium))
                        .foregroundColor(commitment.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(commitment.color.opacity(0.15))
                        )
                    
                    Spacer()
                }
                
                Text(timeRangeText)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Button(action: { showingOptions = true }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .confirmationDialog("Options", isPresented: $showingOptions) {
            Button("Edit") { onEdit() }
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private var frequencyText: String {
        switch commitment.cadence {
        case .daily:
            return "Daily"
        case .weekdays:
            return "Weekdays"
        case .custom:
            if commitment.customDays.count == 7 {
                return "Daily"
            } else if commitment.customDays.count <= 3 {
                return commitment.customDays.map { String($0.rawValue.prefix(3)) }.joined(separator: ", ")
            } else {
                return "\(commitment.customDays.count) days/week"
            }
        }
    }
    
    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        if let startDate = dateFromHHMM(commitment.startTime),
           let endDate = dateFromHHMM(commitment.endTime) {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
        return "\(commitment.startTime) - \(commitment.endTime)"
    }
}

private struct CommitmentEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var commitment: RecurringCommitment?
    let onSave: (RecurringCommitment) -> Void
    
    @State private var title = ""
    @State private var selectedIcon = "calendar"
    @State private var selectedColor = "blue"
    @State private var cadence: RecurringCadence = .daily
    @State private var customDays: Set<Weekday> = []
    @State private var startTime = Date()
    @State private var endTime = Date()
    
    @State private var showIconPicker = false
    @State private var showColorPicker = false
    
    private let icons = [
        "calendar", "dumbbell", "figure.walk", "bicycle", "figure.swimming",
        "music.note", "paintbrush.fill", "book.fill", "graduationcap.fill",
        "stethoscope", "cross.fill", "leaf", "pawprint", "car.fill",
        "airplane", "building.2.fill", "house.fill", "person.2.fill",
        "gamecontroller.fill", "tv.fill", "camera.fill", "guitars"
    ]
    
    private let colors = [
        ("red", Color.red), ("orange", Color.orange), ("yellow", Color.yellow),
        ("green", Color.green), ("mint", Color.mint), ("teal", Color.teal),
        ("cyan", Color.cyan), ("blue", Color.blue), ("indigo", Color.indigo),
        ("purple", Color.purple), ("pink", Color.pink), ("accent", AppTheme.Colors.accent)
    ]
    
    var isEditing: Bool {
        commitment != nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        previewCard
                        
                        VStack(spacing: 20) {
                            titleField
                            frequencySection
                            timeSection
                            appearanceSection
                        }
                        .padding(.horizontal, 24)
                        
                        saveButton
                            .padding(.horizontal, 24)
                        
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 20)
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle(isEditing ? "Edit Commitment" : "New Commitment")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .onAppear {
            setupInitialValues()
        }
        .sheet(isPresented: $showIconPicker) {
            CommitmentIconPickerSheet(selectedIcon: $selectedIcon, icons: icons)
        }
        .sheet(isPresented: $showColorPicker) {
            CommitmentColorPickerSheet(selectedColor: $selectedColor, colors: colors)
        }
    }
    
    private var previewCard: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(currentColor.opacity(0.2))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: selectedIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(currentColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title.isEmpty ? "Commitment Title" : title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                
                Text(schedulePreview)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }
    
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title")
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.7))
            
            TextField("Enter commitment title", text: $title)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
        }
    }
    
    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Frequency")
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: 8) {
                ForEach(RecurringCadence.allCases) { cadenceOption in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            cadence = cadenceOption
                        }
                    }) {
                        Text(cadenceOption.rawValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(cadence == cadenceOption ? .white : .white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(cadence == cadenceOption ? AppTheme.Colors.primary : .white.opacity(0.1))
                            )
                    }
                }
            }
            
            if cadence == .custom {
                customDaysSelection
            }
        }
    }
    
    private var customDaysSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Days")
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.7))
            
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 2), spacing: 8) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if customDays.contains(day) {
                                customDays.remove(day)
                            } else {
                                customDays.insert(day)
                            }
                        }
                    }) {
                        Text(day.rawValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(customDays.contains(day) ? .white : .white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(customDays.contains(day) ? currentColor : .white.opacity(0.1))
                            )
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private var timeSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Time")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                
                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(CompactDatePickerStyle())
                    .labelsHidden()
                    .colorScheme(.dark)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text("End Time")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                
                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(CompactDatePickerStyle())
                    .labelsHidden()
                    .colorScheme(.dark)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    private var appearanceSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Button(action: { showIconPicker = true }) {
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: selectedIcon)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(currentColor)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Button(action: { showColorPicker = true }) {
                    Circle()
                        .fill(currentColor)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.2), lineWidth: 2)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    private var saveButton: some View {
        Button(action: saveCommitment) {
            Text(isEditing ? "Save Changes" : "Create Commitment")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.Colors.primary)
                        .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 4, y: 2)
                )
        }
        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || (cadence == .custom && customDays.isEmpty))
        .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty || (cadence == .custom && customDays.isEmpty) ? 0.6 : 1.0)
    }
    
    private var currentColor: Color {
        Color.activityColor(selectedColor)
    }
    
    private var schedulePreview: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeRange = "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
        
        switch cadence {
        case .daily: return "Daily • \(timeRange)"
        case .weekdays: return "Weekdays • \(timeRange)"
        case .custom:
            if customDays.isEmpty {
                return "Custom • \(timeRange)"
            } else {
                let dayText = customDays.count == 7 ? "Daily" :
                             customDays.count <= 3 ? customDays.map { String($0.rawValue.prefix(3)) }.joined(separator: ", ") :
                             "\(customDays.count) days/week"
                return "\(dayText) • \(timeRange)"
            }
        }
    }
    
    private func setupInitialValues() {
        if let existing = commitment {
            title = existing.title
            selectedIcon = existing.icon
            selectedColor = existing.colorName
            cadence = existing.cadence
            customDays = Set(existing.customDays)
            
            if let start = dateFromHHMM(existing.startTime) {
                startTime = start
            }
            if let end = dateFromHHMM(existing.endTime) {
                endTime = end
            }
        } else {
            let calendar = Calendar.current
            let now = Date()
            
            if let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now) {
                startTime = start
            }
            if let end = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: now) {
                endTime = end
            }
            
            cadence = .daily
            customDays = Set(Weekday.allCases)
        }
    }
    
    private func saveCommitment() {
        let finalDays: [Weekday]
        switch cadence {
        case .daily:
            finalDays = Weekday.allCases
        case .weekdays:
            finalDays = [.monday, .tuesday, .wednesday, .thursday, .friday]
        case .custom:
            finalDays = Array(customDays)
        }
        
        let newCommitment = RecurringCommitment(
            id: commitment?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            colorName: selectedColor,
            cadence: cadence,
            customDays: finalDays,
            startTime: startTime.hhmmString,
            endTime: endTime.hhmmString
        )
        
        onSave(newCommitment)
        dismiss()
    }
}

private struct CommitmentIconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String
    let icons: [String]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4), spacing: 20) {
                        ForEach(icons, id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                                dismiss()
                            }) {
                                Circle()
                                    .fill(.white.opacity(selectedIcon == icon ? 0.2 : 0.1))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: icon)
                                            .font(.system(size: 24, weight: .medium))
                                            .foregroundColor(.white)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(AppTheme.Colors.primary, lineWidth: selectedIcon == icon ? 3 : 0)
                                    )
                                    .scaleEffect(selectedIcon == icon ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIcon == icon)
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

private struct CommitmentColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: String
    let colors: [(String, Color)]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4), spacing: 20) {
                        ForEach(colors, id: \.0) { colorName, color in
                            Button(action: {
                                selectedColor = colorName
                                dismiss()
                            }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Circle()
                                            .stroke(.white, lineWidth: selectedColor == colorName ? 4 : 1)
                                    )
                                    .shadow(color: color.opacity(0.3), radius: 6, y: 3)
                                    .scaleEffect(selectedColor == colorName ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedColor == colorName)
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}
