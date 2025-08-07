//
//  AccountView.swift
//  TimeFlow
//
//  Created by Adam Ress on 5/29/25.
//

import SwiftUI

struct AccountView: View {
    
    @Environment(ContentModel.self) private var contentModel
    @StateObject private var notificationManager = NotificationManager.shared
    
    @State private var showSignOutConfirmation = false
    @State private var showSubscriptionSheet = false
    @State private var showEventColorsSheet = false
    @State private var showAwakeHoursSheet = false
    @State private var showLifeStageFlow = false
    @State private var showScheduleSheet = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showProfileSheet = false
    @State private var showPrivacySheet = false
    @State private var showNotificationSheet = false
    
    // Auto-scheduling state
    @State private var autoScheduleEnabled = UserDefaults.standard.bool(forKey: "autoScheduleEnabled")
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    
    private var user: User? {
        contentModel.user
    }
    
    var body: some View {
        ZStack {
            // Professional dark background
            LinearGradient(
                colors: [
                    AppTheme.Colors.background,
                    AppTheme.Colors.secondary.opacity(0.2),
                    AppTheme.Colors.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        headerSection
                        
                        // Account Information
                        accountSection
                        
                        // Subscription
                        subscriptionSection
                        
                        // Schedule & Time 
                        scheduleSection
                        
                        // Personalization 
                        personalizationSection
                        
                        // Life Stage 
                        lifeStageSection
                        
                        // Account Actions
                        actionsSection
                        
                        Spacer(minLength: 100) // Space for tab bar
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
                .preferredColorScheme(.dark)
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileEditSheet()
        }
        .sheet(isPresented: $showPrivacySheet) {
            PrivacySheet()
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            SubscriptionManagementSheet()
        }
        .sheet(isPresented: $showEventColorsSheet) {
            EventColorsSheet()
        }
        .sheet(isPresented: $showAwakeHoursSheet) {
            AwakeHoursConfigSheet()
        }
        .sheet(isPresented: $showLifeStageFlow) {
            LifeStageChangeFlow()
        }
        .sheet(isPresented: $showScheduleSheet) {
            ScheduleManagementSheet()
        }
        .sheet(isPresented: $showNotificationSheet) {
            NotificationSettingsSheet()
        }
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .onAppear {
            Task {
                permissionStatus = await notificationManager.checkPermissionStatus()
            }
        }
        .onChange(of: autoScheduleEnabled) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                contentModel.toggleAutoScheduling(newValue)
            }
        }
    }
}

// MARK: - Header Section
private extension AccountView {
    
    var headerSection: some View {
        VStack(spacing: 16) {
            // Profile Circle
            Circle()
                .fill(AppTheme.Colors.primary.opacity(0.15))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(user?.name.prefix(1).uppercased() ?? "U")
                        .font(.title.weight(.semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                )
            
            // User Info
            VStack(spacing: 4) {
                Text(user?.name ?? "User")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(user?.email ?? "user@example.com")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                
                // Age Group Badge
                if let ageGroup = user?.ageGroup {
                    Text(ageGroup.rawValue)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(ageGroup.themeColor.opacity(0.2))
                        )
                        .foregroundColor(ageGroup.themeColor)
                }
            }
        }
        .padding(.top, 10)
    }
}

// MARK: - Account Section
private extension AccountView {
    
    var accountSection: some View {
        SettingsSection(title: "Account") {
            SettingsRow(
                icon: "person.circle",
                title: "Profile Information",
                subtitle: "Name, email, and basic info",
                showChevron: true
            ) {
                showProfileSheet = true
            }
            
            SettingsRow(
                icon: "doc.text",
                title: "Terms & Privacy Policy",
                subtitle: "Legal agreements and policies",
                showChevron: true
            ) {
                showPrivacySheet = true
            }
        }
    }
}

// MARK: - Subscription Section
private extension AccountView {
    
    var subscriptionSection: some View {
        SettingsSection(title: "Subscription") {
            SettingsRow(
                icon: "crown.fill",
                title: user?.subscribed == true ? "TimeFlow Pro" : "Upgrade to Pro",
                subtitle: user?.subscribed == true ? "Active subscription" : "Unlock all features",
                showChevron: true,
                accentColor: user?.subscribed == true ? .green : AppTheme.Colors.primary
            ) {
                showSubscriptionSheet = true
            }
            
            if user?.subscribed == true {
                SettingsRow(
                    icon: "creditcard",
                    title: "Manage Subscription",
                    subtitle: "Billing and payment options",
                    showChevron: true
                ) {
                    // Navigate to billing management
                }
            }
        }
    }
}

// MARK: - Schedule Section
private extension AccountView {
    
    var scheduleSection: some View {
        SettingsSection(title: "Schedule & Time") {
            SettingsRow(
                icon: "moon.zzz",
                title: "Sleep Schedule",
                subtitle: awakeHoursSubtitle,
                showChevron: true
            ) {
                showAwakeHoursSheet = true
            }
            
            // Auto-scheduling toggle
            HStack(spacing: 16) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Smart Schedule Generation")
                        .font(.body.weight(.medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Morning notification + automatic schedule when possible")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Toggle("", isOn: $autoScheduleEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            
            if let ageGroup = user?.ageGroup {
                switch ageGroup {
                case .middleSchool, .highSchool:
                    SettingsRow(
                        icon: "building.2",
                        title: "School Hours",
                        subtitle: schoolHoursSubtitle,
                        showChevron: true
                    ) {
                        showScheduleSheet = true
                    }
                    
                case .college:
                    SettingsRow(
                        icon: "book.closed",
                        title: "Class Schedule",
                        subtitle: "\(user?.collegeCourses.count ?? 0) courses",
                        showChevron: true
                    ) {
                        showScheduleSheet = true
                    }
                    
                case .youngProfessional:
                    SettingsRow(
                        icon: "briefcase",
                        title: "Work Schedule",
                        subtitle: workHoursSubtitle,
                        showChevron: true
                    ) {
                        showScheduleSheet = true
                    }
                }
            }
            
            SettingsRow(
                icon: "bell",
                title: "Notifications",
                subtitle: notificationSubtitle,
                showChevron: true
            ) {
                showNotificationSheet = true
            }
        }
    }
    
    private var awakeHoursSubtitle: String {
        guard let awakeHours = user?.awakeHours else { return "Not set" }
        return "\(formatTime(awakeHours.wakeTime)) - \(formatTime(awakeHours.sleepTime))"
    }
    
    private var schoolHoursSubtitle: String {
        guard let schoolHours = user?.schoolHours else { return "Not set" }
        return "\(formatTime(schoolHours.startTime)) - \(formatTime(schoolHours.endTime))"
    }
    
    private var workHoursSubtitle: String {
        let workDays = user?.workHours.filter { $0.enabled }.count ?? 0
        return "\(workDays) days per week"
    }
    
    private var notificationSubtitle: String {
        switch permissionStatus {
        case .denied:
            return "Disabled in system settings"
        case .authorized:
            let morningEnabled = notificationManager.isMorningNotificationEnabled()
            let eveningEnabled = notificationManager.isEveningNotificationEnabled()
            let enabledCount = (morningEnabled ? 1 : 0) + (eveningEnabled ? 1 : 0)
            return "\(enabledCount) of 2 enabled"
        case .notDetermined:
            return "Not configured"
        case .provisional:
            return "Provisional access"
        case .ephemeral:
            return "Limited access"
        @unknown default:
            return "Unknown status"
        }
    }
    
    private func formatTime(_ timeString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        if let date = formatter.date(from: timeString) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return timeString
    }
}

// MARK: - Personalization Section
private extension AccountView {
    
    var personalizationSection: some View {
        SettingsSection(title: "Personalization") {
            SettingsRow(
                icon: "paintpalette.fill",
                title: "Event Colors",
                subtitle: "Customize your activity colors",
                showChevron: true
            ) {
                showEventColorsSheet = true
            }
        }
    }
}

// MARK: - Life Stage Section
private extension AccountView {
    
    var lifeStageSection: some View {
        SettingsSection(title: "Life Changes") {
            SettingsRow(
                icon: "graduationcap",
                title: "Change Life Stage",
                subtitle: "Currently: \(user?.ageGroup.rawValue ?? "Not set")",
                showChevron: true,
                accentColor: .orange
            ) {
                showLifeStageFlow = true
            }
        }
    }
}

// MARK: - Actions Section
private extension AccountView {
    
    var actionsSection: some View {
        SettingsSection(title: "Account Actions") {
            SettingsRow(
                icon: "arrow.right.square",
                title: "Sign Out",
                subtitle: "Sign out of your account",
                showChevron: false,
                accentColor: .orange
            ) {
                showSignOutConfirmation = true
            }
            
            SettingsRow(
                icon: "trash",
                title: "Delete Account",
                subtitle: "Permanently delete your account",
                showChevron: false,
                accentColor: .red
            ) {
                showDeleteAccountConfirmation = true
            }
        }
    }
}

// MARK: - Helper Methods
private extension AccountView {
    
    func signOut() {
        do {
            try contentModel.signOut()
            // Additional cleanup logic might be required here, e.g., clearing local storage, cache, etc.
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    func deleteAccount() {
        // Implement account deletion logic
        // Ensure to handle errors appropriately and provide feedback to the user
        Task {
            do {
                try await contentModel.deleteUserAccount()
                print("Account deleted successfully")
                // Additional cleanup or navigation logic might be required here
            } catch {
                print("Error deleting account: \(error.localizedDescription)")
                // Handle error, potentially display an alert to the user
            }
        }
    }
}

// MARK: - Settings Components
private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Colors.cardBackground.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.Colors.overlay.opacity(0.3), lineWidth: 0.5)
                    )
            )
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let showChevron: Bool
    var accentColor: Color = AppTheme.Colors.textSecondary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(accentColor)
                    .frame(width: 24, height: 24)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Profile Edit Sheet
private struct ProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ContentModel.self) private var contentModel
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.background)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSaving ? "Saving..." : "Save") {
                        saveProfile()
                    }
                    .disabled(isSaving || name.isEmpty || email.isEmpty)
                    .foregroundColor(isSaving ? AppTheme.Colors.textTertiary : AppTheme.Colors.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            name = contentModel.user?.name ?? ""
            email = contentModel.user?.email ?? ""
        }
    }
    
    private func saveProfile() {
        isSaving = true
        
        // Update the user model
        contentModel.user?.name = name
        contentModel.user?.email = email
        
        // Save to Firestore
        Task {
            do {
                try await contentModel.saveUserInfo()
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    // Show error to user
                    print("Error saving profile: \(error)")
                }
            }
        }
    }
}

// MARK: - Privacy Sheet
private struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Privacy Policy Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Privacy Policy")
                            .font(.title2.weight(.bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text(privacyPolicyText)
                            .font(.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineSpacing(4)
                    }
                    
                    Divider()
                        .background(AppTheme.Colors.overlay)
                    
                    // Terms of Service Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Terms of Service")
                            .font(.title2.weight(.bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text(termsOfServiceText)
                            .font(.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineSpacing(4)
                    }
                }
                .padding(24)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Legal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var privacyPolicyText: String {
        """
        TimeFlow is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our app.
        
        Information We Collect:
        • Personal information you provide (name, email)
        • Schedule and goal data you input
        • Usage analytics to improve our service
        
        How We Use Your Information:
        • To provide and improve our scheduling services
        • To sync your data across devices
        • To send important updates about your account
        
        Data Security:
        We use industry-standard encryption to protect your data. Your personal information is stored securely and never sold to third parties.
        
        Your Rights:
        You can request to export or delete your data at any time through your account settings.
        """
    }
    
    private var termsOfServiceText: String {
        """
        By using TimeFlow, you agree to these Terms of Service.
        
        Acceptable Use:
        • Use the app for personal scheduling and productivity
        • Do not attempt to reverse engineer or hack the service
        • Respect other users and our support team
        
        Subscription Terms:
        • Pro subscriptions are billed monthly or annually
        • You can cancel anytime through your account settings
        • Refunds are handled according to app store policies
        
        Limitation of Liability:
        TimeFlow provides scheduling assistance but you are responsible for your own time management and commitments.
        
        Changes to Terms:
        We may update these terms occasionally. Continued use of the app constitutes acceptance of any changes.
        """
    }
}

// MARK: - Event Colors Sheet
private struct EventColorsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ContentModel.self) private var contentModel
    
    @State private var eventColors: [String] = []
    @State private var isSaving = false
    
    private let availableColors = [
        "red", "orange", "yellow", "green", "mint", "teal", 
        "cyan", "blue", "indigo", "purple", "pink", "maroon"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Professional dark background
                LinearGradient(
                    colors: [
                        AppTheme.Colors.background,
                        AppTheme.Colors.secondary.opacity(0.2),
                        AppTheme.Colors.background
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Event Colors")
                            .font(.title2.weight(.bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Drag to reorder colors for your activities")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Color Grid
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 16) {
                            ForEach(Array(eventColors.enumerated()), id: \.offset) { index, colorName in
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.activityColor(colorName))
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Text("\(index + 1)")
                                                .font(.caption.weight(.bold))
                                                .foregroundColor(.white)
                                        )
                                    
                                    Text(colorName.capitalized)
                                        .font(.caption)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                .onDrag {
                                    NSItemProvider(object: colorName as NSString)
                                }
                                .onDrop(of: [.text], delegate: ColorDropDelegate(
                                    item: colorName,
                                    items: $eventColors
                                ))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSaving ? "Saving..." : "Save") {
                        saveColors()
                    }
                    .disabled(isSaving)
                    .foregroundColor(isSaving ? AppTheme.Colors.textTertiary : AppTheme.Colors.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            //eventColors = contentModel.user?.eventColorsArray ?? availableColors
        }
    }
    
    private func saveColors() {
        isSaving = true
        
        // Update the user model
        //contentModel.user?.eventColorsArray = eventColors
        
        // Save to Firestore
        Task {
            do {
                try await contentModel.saveUserInfo()
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    print("Error saving colors: \(error)")
                }
            }
        }
    }
}

// Color Drop Delegate for drag and drop reordering
private struct ColorDropDelegate: DropDelegate {
    let item: String
    @Binding var items: [String]
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = info.itemProviders(for: [.text]).first else { return }
        
        draggedItem.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
            guard let data = data as? Data,
                  let draggedColorName = String(data: data, encoding: .utf8),
                  let fromIndex = items.firstIndex(of: draggedColorName),
                  let toIndex = items.firstIndex(of: item) else { return }
            
            DispatchQueue.main.async {
                if fromIndex != toIndex {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        items.move(fromOffsets: IndexSet([fromIndex]), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                    }
                }
            }
        }
    }
}

// MARK: - Awake Hours Config Sheet
private struct AwakeHoursConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ContentModel.self) private var contentModel
    
    @State private var awakeHours = AwakeHours(wakeTime: "07:00", sleepTime: "23:00")
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            VStack {
                ScheduleTimesSettings(
                    awakeHours: $awakeHours,
                    isSaving: $isSaving
                ) {
                    saveAwakeHours()
                }
            }
            .navigationTitle("Sleep Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .onAppear {
            awakeHours = contentModel.user?.awakeHours ?? AwakeHours(wakeTime: "07:00", sleepTime: "23:00")
        }
    }
    
    private func saveAwakeHours() {
        isSaving = true
        
        // Update the user model
        contentModel.user?.awakeHours = awakeHours
        
        // Save to Firestore and reschedule notifications
        Task {
            do {
                try await contentModel.saveUserInfo()
                // Reschedule notifications with new wake/sleep times
                await contentModel.scheduleUserNotifications()
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    print("Error saving awake hours: \(error)")
                }
            }
        }
    }
}

// MARK: - Life Stage Change Flow
private struct LifeStageChangeFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ContentModel.self) private var contentModel
    
    @State private var currentStep: LifeStageStep = .selectAgeGroup
    @State private var newAgeGroup: AgeGroup?
    @State private var tempUser: User = User()
    @State private var isSaving = false
    
    enum LifeStageStep {
        case selectAgeGroup
        case configureSchedule
        case complete
    }
    
    var body: some View {
        NavigationStack {
            switch currentStep {
            case .selectAgeGroup:
                SchoolLevelViewSettings { selectedAgeGroup in
                    newAgeGroup = selectedAgeGroup
                    tempUser = contentModel.user ?? User()
                    tempUser.ageGroup = selectedAgeGroup
                    currentStep = .configureSchedule
                }
                .navigationTitle("Change Life Stage")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
            case .configureSchedule:
                if let ageGroup = newAgeGroup {
                    Group {
                        switch ageGroup {
                        case .middleSchool, .highSchool:
                            SchoolHoursViewSettings(
                                startTime: $tempUser.schoolHours.startTime,
                                endTime: $tempUser.schoolHours.endTime,
                                isSaving: $isSaving
                            ) {
                                completeLifeStageChange()
                            }
                        case .college:
                            CollegeScheduleViewSettings(
                                courses: $tempUser.collegeCourses,
                                isSaving: $isSaving
                            ) {
                                completeLifeStageChange()
                            }
                        case .youngProfessional:
                            WorkHoursViewSettings(
                                workHours: $tempUser.workHours,
                                isSaving: $isSaving
                            ) {
                                completeLifeStageChange()
                            }
                        }
                    }
                    .navigationTitle("Configure Schedule")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Back") {
                                currentStep = .selectAgeGroup
                            }
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                
            case .complete:
                EmptyView()
            }
        }
    }
    
    private func completeLifeStageChange() {
        isSaving = true
        
        // Update the actual user model with all changes
        contentModel.user = tempUser
        
        // Save to Firestore
        Task {
            do {
                try await contentModel.saveUserInfo()
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    print("Error saving life stage change: \(error)")
                }
            }
        }
    }
}

// MARK: - Schedule Management Sheet
private struct ScheduleManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ContentModel.self) private var contentModel
    
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Group {
                if let ageGroup = contentModel.user?.ageGroup {
                    switch ageGroup {
                    case .middleSchool, .highSchool:
                        SchoolHoursViewSettings(
                            startTime: Binding(
                                get: { contentModel.user?.schoolHours.startTime ?? "08:00" },
                                set: { contentModel.user?.schoolHours.startTime = $0 }
                            ),
                            endTime: Binding(
                                get: { contentModel.user?.schoolHours.endTime ?? "15:00" },
                                set: { contentModel.user?.schoolHours.endTime = $0 }
                            ),
                            isSaving: $isSaving
                        ) {
                            saveAndDismiss()
                        }
                    case .college:
                        CollegeScheduleViewSettings(
                            courses: Binding(
                                get: { contentModel.user?.collegeCourses ?? [] },
                                set: { contentModel.user?.collegeCourses = $0 }
                            ),
                            isSaving: $isSaving
                        ) {
                            saveAndDismiss()
                        }
                    case .youngProfessional:
                        WorkHoursViewSettings(
                            workHours: Binding(
                                get: { contentModel.user?.workHours ?? [] },
                                set: { contentModel.user?.workHours = $0 }
                            ),
                            isSaving: $isSaving
                        ) {
                            saveAndDismiss()
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text("No schedule configuration available")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("Please set your life stage first")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    .padding()
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
    }
    
    private func saveAndDismiss() {
        isSaving = true
        
        Task {
            do {
                try await contentModel.saveUserInfo()
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    print("Error saving schedule: \(error)")
                }
            }
        }
    }
}

// MARK: - Settings-specific Views

private struct ScheduleTimesSettings: View {
    @Binding var awakeHours: AwakeHours
    @Binding var isSaving: Bool
    let onSave: () -> Void
    
    var body: some View {
        ZStack {
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
            
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 8) {
                    Text("When do you usually sleep?")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                    Text("Drag the handles to set wake-up and bedtime.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal)
                
                BedtimeDial(
                    wake: Binding(
                        get: { toMinutes(awakeHours.wakeTime) },
                        set: { awakeHours.wakeTime = toHHMM(from: $0) }
                    ),
                    bed: Binding(
                        get: { toMinutes(awakeHours.sleepTime) },
                        set: { awakeHours.sleepTime = toHHMM(from: $0) }
                    ),
                    accent: AppTheme.Colors.primary
                )
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                
                Spacer()
                
                Button(action: onSave) {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSaving ? Color.gray : AppTheme.Colors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .padding(.bottom, 22)
                }
                .disabled(isSaving)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct SchoolLevelViewSettings: View {
    let onContinue: (AgeGroup) -> Void
    
    @State private var selection: AgeGroup? = nil
    // Temp fix: .constant(nil)
    
    private let grid = [GridItem(.adaptive(minimum: 150), spacing: 16)]
    
    var body: some View {
        ZStack {
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
                VStack(spacing: 10) {
                    Text("Tell us where you are")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                    Text("We'll tailor the planner around your day-to-day reality.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal)
                }
                .padding(.top, 60)
                
                LazyVGrid(columns: grid, spacing: 18) {
                    ForEach(AgeGroup.allCases) { ageGroup in
                        let picked = selection == ageGroup
                        VStack(spacing: 14) {
                            Image(systemName: ageGroup.icon)
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundColor(picked ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                            Text(ageGroup.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .themeCardWithStroke(selected: picked, strokeColor: AppTheme.Colors.primary)
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                        .onTapGesture {
                            withAnimation(.easeInOut) {
                                selection = ageGroup
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button {
                    if let s = selection {
                        onContinue(s)
                    }
                } label: {
                    Text("Continue")
                        .fontWeight(.semibold)
                }
                .themeButton(enabled: selection != nil, color: AppTheme.Colors.primary)
                .disabled(selection == nil)
                .padding(.horizontal)
                .padding(.bottom, 22)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct SchoolHoursViewSettings: View {
    @Binding var startTime: String
    @Binding var endTime: String
    @Binding var isSaving: Bool
    let onSave: () -> Void
    
    @State private var startHour: CGFloat = 8.0   // 8am
    @State private var endHour: CGFloat = 15.0    // 3pm
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    
    // 6am to 4pm range
    private let trackHeight: CGFloat = 400.0
    private let minHour: CGFloat = 6.0
    private let maxHour: CGFloat = 16.0
    
    private var hourRange: CGFloat {
        maxHour - minHour
    }
    
    private var startOffset: CGFloat {
        ((startHour - minHour) / hourRange) * trackHeight
    }
    
    private var endOffset: CGFloat {
        ((endHour - minHour) / hourRange) * trackHeight
    }
    
    private var validRange: Bool { endHour > startHour + 0.25 }
    
    var body: some View {
        ZStack {
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
                VStack(spacing: 12) {
                    Text("When are you in school?")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("We'll protect these hours Monday–Friday")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 40)
                
                Spacer()
                    .frame(height: 40)
                
                // Single grouped card
                VStack(spacing: 20) {
                    Text("School hours")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    verticalTimeBarPicker
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            (isDraggingStart || isDraggingEnd) ? AppTheme.Colors.primary : Color.clear,
                            lineWidth: 2
                        )
                        .shadow(
                            color: (isDraggingStart || isDraggingEnd) ? AppTheme.Colors.primary.opacity(0.3) : Color.clear,
                            radius: (isDraggingStart || isDraggingEnd) ? 8 : 0
                        )
                        .animation(.easeInOut(duration: 0.2), value: isDraggingStart || isDraggingEnd)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                
                Spacer()
                
                Button {
                    if validRange {
                        onSave()
                    }
                } label: {
                    Text("Save")
                        .fontWeight(.semibold)
                }
                .themeButton(enabled: validRange, color: AppTheme.Colors.primary)
                .disabled(!validRange)
                .padding(.horizontal)
                .padding(.bottom, 22)
            }
        }
        .onAppear {
            // Parse existing times
            startHour = timeStringToHour(startTime)
            endHour = timeStringToHour(endTime)
        }
        .onChange(of: startHour) { oldValue, newValue in
            startTime = hourToTimeString(newValue)
        }
        .onChange(of: endHour) { oldValue, newValue in
            endTime = hourToTimeString(newValue)
        }
        .preferredColorScheme(.dark)
    }
    
    private var verticalTimeBarPicker: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                timeLabels
                    .frame(width: 60)
                timeTrackContainer
                    .frame(width: 200, height: trackHeight)
            }
            
            if !validRange {
                Text("End time must be at least 15 minutes after start time")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
    }
    
    private var timeLabels: some View {
        VStack(spacing: 0) {
            ForEach(Array(stride(from: 6, through: 16, by: 2)), id: \.self) { hour in
                let displayHour = hour > 12 ? hour - 12 : hour
                let ampm = hour >= 12 ? "PM" : "AM"
                Text("\(displayHour) \(ampm)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                if hour != 16 {
                    Spacer()
                }
            }
        }
    }
    
    private var timeTrackContainer: some View {
        ZStack(alignment: .center) {
            hourTicks
            backgroundTrack
            selectedRange
            startThumb
            endThumb
        }
        .frame(width: 200, height: trackHeight)
    }
    
    private var hourTicks: some View {
        Group {
            // Major ticks every hour
            ForEach(6...16, id: \.self) { hour in
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 100, height: 1)
                    .offset(y: ((CGFloat(hour) - minHour) / hourRange * trackHeight) - trackHeight / 2)
            }
            
            // Minor ticks every 30 minutes
            ForEach(Array(stride(from: 6.5, through: 15.5, by: 1.0)), id: \.self) { half in
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 80, height: 1)
                    .offset(y: ((half - minHour) / hourRange * trackHeight) - trackHeight / 2)
            }
        }
    }
    
    private var backgroundTrack: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 40, height: trackHeight)
    }
    
    private var selectedRange: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(AppTheme.Colors.primary.opacity(0.3))
            .frame(width: 40, height: max(0, endOffset - startOffset))
            .offset(y: (startOffset + endOffset) / 2 - trackHeight / 2)
    }
    
    private var startThumb: some View {
        HStack {
            Text(formatTimeDisplay(startHour))
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.Colors.primary.opacity(0.8))
                .cornerRadius(8)
                .foregroundColor(.white)
                .transition(.opacity)
        }
        .scaleEffect(isDraggingStart ? 1.2 : 1.0)
        .offset(y: startOffset - trackHeight / 2)
        .gesture(startDragGesture)
    }

    private var endThumb: some View {
        HStack {
            Text(formatTimeDisplay(endHour))
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.Colors.primary.opacity(0.8))
                .cornerRadius(8)
                .foregroundColor(.white)
                .transition(.opacity)
        }
        .scaleEffect(isDraggingEnd ? 1.2 : 1.0)
        .offset(y: endOffset - trackHeight / 2)
        .gesture(endDragGesture)
    }
    
    private var startDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDraggingStart = true
                let delta = value.translation.height / trackHeight * hourRange
                var newHour = startHour + delta
                newHour = max(minHour, min(endHour - 0.25, newHour))
                let snappedHour = snapToFifteenMinutes(newHour)
                startHour = snappedHour
            }
            .onEnded { _ in
                isDraggingStart = false
            }
    }
    
    private var endDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDraggingEnd = true
                let delta = value.translation.height / trackHeight * hourRange
                var newHour = endHour + delta
                newHour = min(maxHour, max(startHour + 0.25, newHour))
                let snappedHour = snapToFifteenMinutes(newHour)
                endHour = snappedHour
            }
            .onEnded { _ in
                isDraggingEnd = false
            }
    }
    
    private func formatTimeDisplay(_ hour: CGFloat) -> String {
        let totalMinutes = round(hour * 60.0)
        let hourInt = Int(totalMinutes / 60)
        let mins = Int(totalMinutes.truncatingRemainder(dividingBy: 60))
        let displayHour = hourInt % 12 == 0 ? 12 : hourInt % 12
        let ampm = hourInt >= 12 ? "PM" : "AM"
        
        return "\(displayHour):\(String(format: "%02d", mins)) \(ampm)"
    }
    
    private func snapToFifteenMinutes(_ hour: CGFloat) -> CGFloat {
        return round(hour * 4.0) / 4.0
    }
    
    private func timeStringToHour(_ timeString: String) -> CGFloat {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2, let h = Double(parts[0]), let m = Double(parts[1]) else { return 8.0 }
        return CGFloat(h + m / 60.0)
    }
    
    private func hourToTimeString(_ hour: CGFloat) -> String {
        let totalMinutes = Int(round(hour * 60.0))
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return String(format: "%02d:%02d", h, m)
    }
}

private struct CollegeScheduleViewSettings: View {
    @Binding var courses: [CollegeCourse]
    @Binding var isSaving: Bool
    let onSave: () -> Void
    
    @State private var editing: CollegeCourse? = nil
    @State private var showSheet = false
    
    private let hourHeight: CGFloat = 38
    private let card = Color(red: 0.13, green: 0.13, blue: 0.15)
    private let weekdays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]
    
    var body: some View {
        ZStack {
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
            
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Edit your classes")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Tap + to insert · tap block to edit")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .multilineTextAlignment(.center)
                
                calendarPanel
                    .padding(.horizontal, 8)
                
                Button {
                    editing = nil
                    showSheet = true
                } label: {
                    Label("Add class", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.Colors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .padding(.horizontal)
                }
                
                Button(action: onSave) {
                    Text("Save")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSaving ? Color.gray.opacity(0.4) : AppTheme.Colors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .disabled(isSaving)
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showSheet) {
            ClassSheet(existing: $editing, accent: AppTheme.Colors.primary) { saveCourse($0) }
        }
        .preferredColorScheme(.dark)
    }
    
    private var calendarPanel: some View {
        VStack(spacing: 0) {
            weekdayHeader
            ScrollView(showsIndicators: true) {
                calendarGrid
                    .frame(height: hourHeight * 18)   // 6 AM→12 AM
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(card)
                .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
        )
    }
    
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdays) { day in
                Text(abbr(for: day))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .background(card.opacity(0.9))
    }
    
    private func abbr(for day: Weekday) -> String {
        switch day {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
    
    private var calendarGrid: some View {
        ZStack(alignment: .topLeading) {
            gridLines
            classBlocks
        }
    }
    
    private var gridLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<18) { _ in
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                Spacer().frame(height: hourHeight - 1)
            }
        }
        .overlay(
            HStack(spacing: 0) {
                ForEach(weekdays) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1)
                    Spacer()
                }
            }
        )
    }
    
    private var classBlocks: some View {
        GeometryReader { geo in
            ForEach($courses) { $course in
                let current = $course.wrappedValue

                if let colIndex = weekdays.firstIndex(of: current.day) {
                    let rect  = frame(for: current)
                    let colW  = geo.size.width / CGFloat(weekdays.count)

                    ClassBlockView(
                        course: current,
                        width:  colW - 4,
                        frame:  (top: rect.minY, height: rect.height),
                        colX:   CGFloat(colIndex) * colW
                    )
                    .onTapGesture {
                        editing   = current
                        showSheet = true
                    }
                }
            }
        }
        .clipped()
    }
    
    private struct ClassBlockView: View {
        let course: CollegeCourse
        let width:  CGFloat
        let frame:  (top: CGFloat, height: CGFloat)
        let colX:   CGFloat

        var body: some View {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.palette(course.colorName))
                .overlay(
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.name).font(.caption).bold()
                        Text(time(from: course.startTime) + " – " + time(from: course.endTime))
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .padding(4),
                    alignment: .topLeading
                )
                .frame(width: width, height: frame.height - 2)
                .position(x: colX + width / 2,
                          y: frame.top + frame.height / 2)
        }

        private func time(from hhmm: String) -> String {
            guard let d = dateFromHHMM(hhmm) else { return hhmm }
            return DateFormatter.localizedString(from: d,
                                          dateStyle: .none,
                                          timeStyle: .short)
        }
    }
    
    private func frame(for course: CollegeCourse) -> CGRect {
        let startH = fractionalHours(from: course.startTime)
        let endH   = fractionalHours(from: course.endTime)

        let top    = CGFloat(startH - 6) * hourHeight
        let height = CGFloat(endH - startH) * hourHeight
        return CGRect(x: 0, y: top, width: 0, height: height)
    }
    
    private func fractionalHours(from hhmm: String) -> Double {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Double(parts[0]), let m = Double(parts[1]) else { return 0 }
        return h + m / 60.0
    }
    
    private func saveCourse(_ c: CollegeCourse) {
        if let i = courses.firstIndex(where: { $0.id == c.id }) {
            if c.name.isEmpty { 
                courses.remove(at: i) 
            } else { 
                courses[i] = c 
            }
        } else { 
            courses.append(c) 
        }
    }
}

private struct WorkHoursViewSettings: View {
    @Binding var workHours: [DayHours]
    @Binding var isSaving: Bool
    let onSave: () -> Void
    
    @State private var copyAlert = false
    
    private let card = Color(red: 0.13, green: 0.13, blue: 0.15)
    
    private var valid: Bool {
        workHours.filter(\.enabled).allSatisfy { $0.endTime > $0.startTime }
    }
    
    var body: some View {
        ZStack {
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

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Set your core work hours")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("We'll avoid scheduling personal tasks inside this window.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
                
                ScrollView {
                    VStack(spacing: 18) {
                        ForEach($workHours) { $row in
                            rowCard($row)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Button("Copy Monday to Tue–Fri") { copyAlert = true }
                    .font(.subheadline.weight(.semibold))
                    .disabled(workHours.isEmpty || !workHours.first!.enabled)
                    .tint(AppTheme.Colors.primary)
                
                Button(action: onSave) {
                    Text("Save")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((valid && !isSaving) ? AppTheme.Colors.primary : Color.gray.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .disabled(!valid || isSaving)
                .padding(.horizontal)
                .padding(.bottom, 26)
            }
        }
        .alert("Copy Monday's hours to Tue–Fri?",
               isPresented: $copyAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Copy", role: .destructive) { copyMonday() }
        }
        .preferredColorScheme(.dark)
    }
    
    private func rowCard(_ binding: Binding<DayHours>) -> some View {
        let startDate = Binding<Date>(
            get: { Date.at(binding.startTime.wrappedValue) },
            set: { binding.startTime.wrappedValue = $0.hhmmString }
        )
        let endDate = Binding<Date>(
            get: { Date.at(binding.endTime.wrappedValue) },
            set: { binding.endTime.wrappedValue = $0.hhmmString }
        )
        
        return VStack(alignment: .leading, spacing: 14) {
            Toggle(binding.day.wrappedValue.rawValue, isOn: binding.enabled)
                .toggleStyle(.switch)
                .font(.headline)
                .tint(AppTheme.Colors.primary)
                .foregroundColor(.white)
            
            if binding.enabled.wrappedValue {
                HStack {
                    DatePicker("", selection: startDate,
                               displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    
                    DatePicker("", selection: endDate,
                               displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.13, green: 0.13, blue: 0.15))
                .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
        )
    }
    
    private func copyMonday() {
        guard let mon = workHours.first else { return }
        for i in 1...4 {
            if i < workHours.count {
                workHours[i].enabled = mon.enabled
                workHours[i].startTime   = mon.startTime
                workHours[i].endTime     = mon.endTime
            }
        }
    }
}

// MARK: - Subscription Management Sheet (Placeholder)
private struct SubscriptionManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("Subscription Management")
                    .font(.title2.bold())
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Coming soon! Manage your TimeFlow Pro subscription here.")
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .background(AppTheme.Colors.background)
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// Helper functions for ScheduleTimes
private func toMinutes(_ hhmm: String) -> Double {
    let comps = hhmm.split(separator: ":").compactMap { Int($0) }
    guard comps.count == 2 else { return 0 }
    return Double((comps[0] * 60) + comps[1])
}

private func toHHMM(from minutes: Double) -> String {
    let h = Int(minutes) / 60 % 24
    let m = Int(minutes) % 60
    return String(format: "%02d:%02d", h, m)
}

// MARK: - Notification Settings Sheet
private struct NotificationSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var morningEnabled = true
    @State private var eveningEnabled = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Professional dark background
                LinearGradient(
                    colors: [
                        AppTheme.Colors.background,
                        AppTheme.Colors.secondary.opacity(0.2),
                        AppTheme.Colors.background
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Notifications")
                                .font(.title2.weight(.bold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("Choose which notifications you'd like to receive")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Permission status section
                        if permissionStatus == .denied {
                            VStack(spacing: 16) {
                                Image(systemName: "bell.slash")
                                    .font(.system(size: 48))
                                    .foregroundColor(.red)
                                
                                Text("Notifications Disabled")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                
                                Text("To receive notifications, please enable them in Settings → TimeFlow → Notifications")
                                    .font(.body)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button("Open Settings") {
                                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(settingsUrl)
                                    }
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.Colors.primary)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .padding(.horizontal)
                            }
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppTheme.Colors.cardBackground.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 20)
                        } else {
                            // Notification types list
                            VStack(spacing: 0) {
                                // Morning Notification
                                HStack(spacing: 16) {
                                    Image(systemName: "sun.max.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.orange)
                                        .frame(width: 24, height: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Morning Schedule")
                                            .font(.body.weight(.medium))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                        
                                        Text("Get notified when you wake up to plan your day")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.Colors.textTertiary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    
                                    Toggle("", isOn: $morningEnabled)
                                        .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .onChange(of: morningEnabled) { _, newValue in
                                    notificationManager.setMorningNotificationEnabled(newValue)
                                }
                                
                                Divider()
                                    .background(AppTheme.Colors.overlay.opacity(0.3))
                                    .padding(.horizontal, 20)
                                
                                // Evening Notification
                                HStack(spacing: 16) {
                                    Image(systemName: "moon.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.blue)
                                        .frame(width: 24, height: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Evening Reminder")
                                            .font(.body.weight(.medium))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                        
                                        Text("Get reminded to wind down before bedtime")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.Colors.textTertiary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    
                                    Toggle("", isOn: $eveningEnabled)
                                        .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .onChange(of: eveningEnabled) { _, newValue in
                                    notificationManager.setEveningNotificationEnabled(newValue)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppTheme.Colors.cardBackground.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(AppTheme.Colors.overlay.opacity(0.3), lineWidth: 0.5)
                                    )
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .onAppear {
            Task {
                permissionStatus = await notificationManager.checkPermissionStatus()
                morningEnabled = notificationManager.isMorningNotificationEnabled()
                eveningEnabled = notificationManager.isEveningNotificationEnabled()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    AccountView()
        .environment(ContentModel())
}
