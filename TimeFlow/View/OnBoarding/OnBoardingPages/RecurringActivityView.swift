//
//  RecurringCommitmentsView.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/29/25.
//

import SwiftUI

struct RecurringCommitmentsView: View {
    
    @Binding var commitments: [RecurringCommitment]
    let themeColor: Color
    @State private var editing: RecurringCommitment?
    @State private var showingSheet = false
    @State private var editMode: EditMode = .inactive
    
    private let card = AppTheme.Colors.cardBackground
    
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
                commitmentList
                addButton
                Spacer(minLength: 12)
                continueButton
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { progressToolbar(currentStep: 5) {
            onContinue()
        } }
        .sheet(isPresented: $showingSheet) {
            AddEditCommitmentSheet(
                existing: $editing,
                onSave: { save($0) },
                themeColor: themeColor
            )
        }
        .environment(\.editMode, $editMode)
        .onAppear {
            withAnimation {
                animateContent = true
            }
        }
    }
}

// MARK: - Header, list, CTA
private extension RecurringCommitmentsView {
    
    var header: some View {
        VStack(spacing: 8) {
            Text("Log your recurring commitments")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text("These happen at the same time every week—never double-booked.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(.top, 12)
        .opacity(animateContent ? 1.0 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.easeOut(duration: 0.8), value: animateContent)
    }
    
    var commitmentList: some View {
        Group {
            if commitments.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    Text("No commitments yet")
                        .font(.headline)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    Text("Add your regular weekly activities")
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
                            ForEach(commitments) { commitment in
                                CommitmentRow(commitment: commitment) {
                                    edit(commitment)
                                } onDelete: {
                                    deleteCommitmentWithAnimation(commitment)
                                }
                                .id(commitment.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .top)),
                                    removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .leading))
                                ))
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxHeight: 320)
                    .onChange(of: commitments.count) { oldCount, newCount in
                        // Scroll to bottom when new commitment is added
                        if newCount > oldCount && newCount > 0 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeOut(duration: 0.8)) {
                                    proxy.scrollTo(commitments.last?.id, anchor: .bottom)
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
            editing = nil
            showingSheet = true
        } label: {
            Label("Add commitment", systemImage: "plus")
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
    
    var continueButton: some View {
        Button(action: onContinue) {
            Text("Continue")
                .fontWeight(.semibold)
        }
        .themeButton(color: themeColor)
    }
}

// MARK: - Commitment row
private struct CommitmentRow: View {
    let commitment: RecurringCommitment
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Circle()
                    .fill(commitmentColor)
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: commitment.icon).foregroundColor(.white))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(commitment.title).fontWeight(.semibold).foregroundColor(AppTheme.Colors.textPrimary)
                    Text(subtitle).font(.caption).foregroundColor(AppTheme.Colors.textTertiary)
                    Text(timeRange).font(.caption2).foregroundColor(AppTheme.Colors.textQuaternary)
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
        .alert("Delete Commitment", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                isDeleting = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onDelete()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(commitment.title)'?")
        }
    }
    
    private var commitmentColor: Color {
        return Color.activityColor(commitment.colorName)
    }
    
    private var subtitle: String {
        switch commitment.cadence {
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .custom: return commitment.customDays.map { $0.rawValue.prefix(3) }.joined(separator: ", ")
        }
    }
    
    private var timeRange: String {
        let startFormatted = formatTimeString(commitment.startTime)
        let endFormatted = formatTimeString(commitment.endTime)
        return "\(startFormatted) - \(endFormatted)"
    }
    
    private func formatTimeString(_ timeString: String) -> String {
        // Convert "HH:mm" format to user-friendly time
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        if let date = formatter.date(from: timeString) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        return timeString // fallback to original if parsing fails
    }
}

// ----------------------------------------------------------------------
//  PROFESSIONAL ADD / EDIT SHEET
// ----------------------------------------------------------------------
private struct AddEditCommitmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var existing: RecurringCommitment?
    let onSave: (RecurringCommitment) -> Void
    let themeColor: Color
    
    @State private var title = ""
    @State private var selectedColor = "blue"
    @State private var selectedIcon = "calendar"
    @State private var cadence: RecurringCadence = .daily
    @State private var customDays: Set<Weekday> = []
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var showAdvanced = false
    
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
    
    private let icons = [
        "calendar", "figure.walk", "dumbbell", "book.fill", "pawprint", "guitars",
        "leaf", "paintbrush.fill", "fork.knife", "car.fill", "bus.fill", "train.fill",
        "airplane", "briefcase.fill", "graduationcap.fill", "stethoscope", "cross.fill",
        "house.fill", "building.2.fill", "storefront", "hammer.fill", "wrench.fill",
        "scissors", "person.2.fill", "heart.fill", "gamecontroller.fill"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerSection
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            mainContent
                                .padding(.horizontal, 24)
                                .padding(.top, 24)
                            
                            VStack(spacing: 16) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showAdvanced.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Text("Appearance & days")
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
                    
                    saveButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                        .background(AppTheme.Colors.background)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showColorPicker) {
                ColorPickerSheet(selectedColor: $selectedColor, colors: colors)
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerSheet(selectedIcon: $selectedIcon)
            }
            .onAppear {
                if existing == nil {
                    cadence = .daily
                    customDays = []
                    
                    let calendar = Calendar.current
                    let today = Date()
                    
                    if let start = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today) {
                        startTime = start
                    }
                    
                    if let end = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today) {
                        endTime = end
                    }
                } else if let existing = existing {
                    populate(from: existing)
                    showAdvanced = existing.cadence == .custom || existing.colorName != "blue" || existing.icon != "calendar"
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
                .foregroundColor(AppTheme.Colors.textTertiary)
                
                Spacer()
                
                Text(existing == nil ? "New Commitment" : "Edit Commitment")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .opacity(0)
                .disabled(true)
            }
            
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
                    Text(title.isEmpty ? "Commitment title" : title)
                        .font(.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(simpleScheduleText)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textTertiary)
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
            titleField
            
            frequencySection
            
            timeSection
        }
    }
    
    private var titleField: some View {
        CleanTextField(
            text: $title,
            placeholder: "Commitment title",
            icon: "calendar"
        )
    }
    
    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frequency")
                .font(.caption.weight(.medium))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            HStack(spacing: 8) {
                FrequencyButton(title: "Daily", cadence: .daily, selectedCadence: $cadence, color: consistentThemeColor)
                FrequencyButton(title: "Weekdays", cadence: .weekdays, selectedCadence: $cadence, color: consistentThemeColor)
                FrequencyButton(title: "Custom", cadence: .custom, selectedCadence: $cadence, color: consistentThemeColor)
            }
            .onChange(of: cadence) { oldValue, newValue in
                if newValue == .custom && oldValue != .custom {
                    // Clear all days when switching to custom
                    customDays = []
                }
            }
            
            if cadence == .custom {
                customDaysSelection
            }
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
    
    private var customDaysSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select days")
                .font(.caption.weight(.medium))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
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
                            .foregroundColor(customDays.contains(day) ? AppTheme.Colors.textPrimary : AppTheme.Colors.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(customDays.contains(day) ? consistentThemeColor : AppTheme.Colors.textPrimary.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(customDays.contains(day) ? Color.clear : AppTheme.Colors.overlay, lineWidth: 1)
                                    )
                            )
                    }
                }
            }
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
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private var timeSection: some View {
        HStack(spacing: 12) {
            startTimeField
            endTimeField
        }
    }
    
    private var startTimeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Start")
                .font(.caption.weight(.medium))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(CompactDatePickerStyle())
                .labelsHidden()
                .colorScheme(.dark)
                .frame(maxWidth: .infinity, alignment: .leading)
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
    
    private var endTimeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("End")
                .font(.caption.weight(.medium))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(CompactDatePickerStyle())
                .labelsHidden()
                .colorScheme(.dark)
                .frame(maxWidth: .infinity, alignment: .leading)
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
    
    private var advancedOptions: some View {
        VStack(spacing: 16) {
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
        Button(action: save) {
            Text(existing == nil ? "Create Commitment" : "Save Changes")
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
        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || (cadence == .custom && customDays.isEmpty))
        .opacity((title.trimmingCharacters(in: .whitespaces).isEmpty || (cadence == .custom && customDays.isEmpty)) ? 0.6 : 1.0)
    }
    
    private var currentColor: Color {
        return Color.activityColor(selectedColor)
    }
    
    private var simpleScheduleText: String {
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
                             customDays.count <= 3 ? customDays.map { $0.rawValue.prefix(3) }.joined(separator: ", ") :
                             "\(customDays.count) days"
                return "\(dayText) • \(timeRange)"
            }
        }
    }
    
    private func populate(from commitment: RecurringCommitment) {
        title = commitment.title
        selectedColor = commitment.colorName
        selectedIcon = commitment.icon
        cadence = commitment.cadence
        customDays = Set(commitment.customDays)
        
        if let start = dateFromHHMM(commitment.startTime) {
            startTime = start
        }
        if let end = dateFromHHMM(commitment.endTime) {
            endTime = end
        }
    }
    
    private func save() {
        let commitmentId = existing?.id ?? UUID()
        
        let commitment = RecurringCommitment(
            id: commitmentId,
            title: title.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            colorName: selectedColor,
            cadence: cadence,
            customDays: cadence == .custom ? Array(customDays) : (cadence == .daily ? Weekday.allCases : [.monday, .tuesday, .wednesday, .thursday, .friday]),
            startTime: startTime.hhmmString,
            endTime: endTime.hhmmString
        )
        
        onSave(commitment)
        dismiss()
    }
}

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

private struct FrequencyButton: View {
    let title: String
    let cadence: RecurringCadence
    @Binding var selectedCadence: RecurringCadence
    let color: Color
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCadence = cadence
            }
        }) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(selectedCadence == cadence ? AppTheme.Colors.textPrimary : AppTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedCadence == cadence ? color : AppTheme.Colors.textPrimary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedCadence == cadence ? Color.clear : AppTheme.Colors.overlay, lineWidth: 1)
                        )
                )
        }
    }
}

private struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
        }
    }
}

private struct ProfessionalTextField: View {
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

// MARK: - Color Picker Sheet
struct ColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: String
    let colors: [(String, Color)]
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
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
                                            .stroke(AppTheme.Colors.overlay, lineWidth: selectedColor == colorName ? 3 : 1)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
        }
    }
}

private extension RecurringCommitmentsView {
    func save(_ commitment: RecurringCommitment) {
        if let i = commitments.firstIndex(where: { $0.id == commitment.id }) {
            commitments[i] = commitment
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                commitments.append(commitment)
            }
        }
    }
    
    func delete(_ commitment: RecurringCommitment) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            commitments.removeAll { $0.id == commitment.id }
        }
    }
    
    func deleteCommitmentWithAnimation(_ commitment: RecurringCommitment) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            commitments.removeAll { $0.id == commitment.id }
        }
    }
    
    func move(from src: IndexSet, to dest: Int) { 
        commitments.move(fromOffsets: src, toOffset: dest) 
    }
    
    func edit(_ commitment: RecurringCommitment) { 
        editing = commitment
        showingSheet = true 
    }
}