//
//  ContentModel.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/11/25.
//  Refactored during code cleanup
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import SwiftUI
import BackgroundTasks

@MainActor @Observable
class ContentModel {
    // MARK: - Published Properties
    
    var user: User? = nil
    var newUser: Bool? = nil
    var loggedIn = false
    var agreedToEULA = true // Give them the benefit of the doubt
    
    // UI loading state
    var isGeneratingSchedule = false
    var madeTodaySchedule = false
    
    // AI Thinking feature
    var showingThinkingOverlay = false
    var currentThinkingStep = ""
    var thinkingStepIndex = 0
    
    // MARK: - Services
    
    private let userService = UserService()
    private let scheduleService = ScheduleService()
    private let creditsService = CreditsService()
    private let historyService = HistoryService()
    private let autoSchedulingService = AutoSchedulingService()
    
    // MARK: - Computed Properties
    
    var userHistory: UserHistory? {
        get { historyService.userHistory }
        set { historyService.userHistory = newValue }
    }
    
    var dailyCredits: Int {
        get { creditsService.dailyCredits }
        set { creditsService.dailyCredits = newValue }
    }
    
    // MARK: - Private Properties
    
    private var userListener: ListenerRegistration?
    let db = Firestore.firestore()
    
    // MARK: - Initialization
    
    init() {
        // Initialize credits service
        creditsService.checkAndResetCreditsIfNeeded()
    }
    
    // MARK: - Authentication & User Management
    
    func currentUID() -> String? {
        userService.currentUID()
    }
    
    func checkLogin() {
        let wasLoggedIn = loggedIn
        loggedIn = userService.isSignedIn()
        
        Logger.debug("🔍 CheckLogin called: Was logged in: \(wasLoggedIn), Now logged in: \(loggedIn)", category: .auth)
        
        // If newly logged in and no user data, try to fetch
        if loggedIn && user == nil {
            Logger.info("🔄 Logged in but no user data, fetching...", category: .auth)
            Task {
                do {
                    try await fetchUser()
                    Logger.info("✅ User data fetched successfully", category: .auth)
                    // Reset credits if needed after login
                    creditsService.checkAndResetCreditsIfNeeded()
                    // Save today's schedule to history
                    if let user = user {
                        await historyService.saveTodaysScheduleToHistory(user: user)
                    }
                    // Check if we need to generate today's schedule
                    if let user = user {
                        await autoSchedulingService.checkAndOfferScheduleGeneration(
                            user: user,
                            scheduleService: scheduleService
                        )
                    }
                } catch {
                    Logger.error("❌ Failed to fetch user data: \(error.localizedDescription)", category: .auth)
                }
            }
        } else if loggedIn {
            // User already logged in, just check credits and schedule
            creditsService.checkAndResetCreditsIfNeeded()
            Task {
                // Save today's schedule to history on app open
                if let user = user {
                    await historyService.saveTodaysScheduleToHistory(user: user)
                    await autoSchedulingService.checkAndOfferScheduleGeneration(
                        user: user,
                        scheduleService: scheduleService
                    )
                }
            }
        }
    }
    
    func signIn(email: String, password: String) async throws {
        try await userService.signIn(email: email, password: password)
        checkLogin()
        try await fetchUser()
        setupUserListener()
        if let user = user {
            await autoSchedulingService.setupAutoScheduling(user: user)
        }
    }
    
    func signOut() throws {
        try userService.signOut()
        loggedIn = false
        user = nil
        userListener?.remove()
        userListener = nil
        checkLogin()
    }
    
    func createAccount(email: String, name: String, password: String) async throws {
        try await userService.createAccount(email: email, name: name, password: password)
        checkLogin()
        try await fetchUser()
        setupUserListener()
        if let user = user {
            await autoSchedulingService.setupAutoScheduling(user: user)
        }
    }
    
    func googleSignIn(windowScene: UIWindowScene?) async throws {
        try await userService.googleSignIn(windowScene: windowScene)
        checkLogin()
        try await fetchUser()
        setupUserListener()
        if let user = user {
            await autoSchedulingService.setupAutoScheduling(user: user)
        }
    }
    
    func resetPassword(email: String) async throws {
        try await userService.resetPassword(email: email)
    }
    
    func checkIfEmailExists(email: String, completion: @escaping (Bool, Error?) -> Void) {
        userService.checkIfEmailExists(email: email, completion: completion)
    }
    
    func fetchUser() async throws {
        user = try await userService.fetchUser()
        
        // Save backup of the successfully decoded schedule
        if let events = user?.currentSchedule, !events.isEmpty {
            scheduleService.saveScheduleBackup(events: events)
        }
        
        // Set up listener if not already done
        if userListener == nil {
            setupUserListener()
        }
        
        // Fetch user history for analytics
        do {
            try await historyService.fetchUserHistory()
        } catch {
            Logger.warning("⚠️ Failed to fetch user history: \(error.localizedDescription)", category: .history)
        }
        
        // Schedule notifications with user's wake/sleep times
        await scheduleUserNotifications()
    }
    
    func saveUserInfo() async throws {
        guard var user = user else { return }
        try await userService.saveUserInfo(user: user)
        self.user = user
    }
    
    func checkNewUser() async throws {
        let isNewUser = try await userService.checkNewUser()
        self.newUser = isNewUser
    }
    
    func onboardingComplete() async throws {
        try await userService.onboardingComplete()
        self.newUser = false
    }
    
    func deleteUserAccount() async throws {
        try await userService.deleteUserAccount()
        user = nil
        userHistory = nil
        loggedIn = false
        userListener?.remove()
        userListener = nil
        NotificationManager.shared.cancelAllNotifications()
    }
    
    func refreshUserData() async throws {
        Logger.info("🔄 Refreshing user data...", category: .auth)
        user = try await userService.fetchUser()
        
        // Save backup of the successfully decoded schedule
        if let events = user?.currentSchedule, !events.isEmpty {
            scheduleService.saveScheduleBackup(events: events, isFromFirebase: true)
        }
        
        // Re-schedule notifications with updated user data
        await scheduleUserNotifications()
    }
    
    // MARK: - User Listener
    
    func setupUserListener() {
        guard let uid = userService.currentUID() else { return }
        
        // Remove existing listener if any
        userListener?.remove()
        
        // Set up new listener for user document changes
        userListener = db.collection("users").document(uid).addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.error("❌ User listener error: \(error.localizedDescription)", category: .auth)
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else { return }
                
                do {
                    Logger.info("🔄 User listener triggered - decoding updated user data", category: .auth)
                    var updatedUser = try snapshot.data(as: User.self)
                    
                    // Ensure name and email are properly populated from the database
                    updatedUser.name = snapshot.get("name") as? String ?? updatedUser.name
                    updatedUser.email = snapshot.get("email") as? String ?? updatedUser.email
                    
                    // Always update to match Firebase exactly
                    self.user = updatedUser
                    
                    Logger.info("✅ User listener update complete - currentSchedule has \(updatedUser.currentSchedule.count) events", category: .auth)
                    
                    // Save backup AFTER updating user, and mark as Firebase-sourced
                    if !updatedUser.currentSchedule.isEmpty {
                        self.scheduleService.saveScheduleBackup(events: updatedUser.currentSchedule, isFromFirebase: true)
                    }
                } catch {
                    Logger.error("❌ Error decoding user update: \(error.localizedDescription)", category: .auth)
                }
            }
        }
    }
    
    // MARK: - Schedule Management
    
    func hasMadeSchedule(wakeHHMM: String, markDone: Bool = false) -> Bool {
        return scheduleService.hasMadeSchedule(wakeHHMM: wakeHHMM, markDone: markDone)
    }
    
    func generateScheduleWithBackgroundSupport(userNote: String = "") async throws -> [Event] {
        guard let user = user else {
            throw NSError(domain: "ContentModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "No user found"])
        }
        
        // Set UI loading state and start thinking overlay
        isGeneratingSchedule = true
        
        // Start thinking simulation
        Task {
            await simulateThinkingProcess()
        }
        
        // Start background task
        BackgroundTaskManager.shared.beginBackgroundTask()
        
        // Cache user data for background access
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: UserDefaultsKeys.cachedUserData)
        }
        
        // Store generation state
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.isGeneratingSchedule)
        UserDefaults.standard.set(userNote, forKey: UserDefaultsKeys.pendingUserNote)
        UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.generationStartTime)
        
        // Schedule background continuation
        BackgroundTaskManager.shared.scheduleBackgroundTask()
        
        defer {
            BackgroundTaskManager.shared.endBackgroundTask()
            UserDefaults.standard.set(false, forKey: UserDefaultsKeys.isGeneratingSchedule)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.pendingUserNote)
            // Reset UI loading state and thinking overlay
            isGeneratingSchedule = false
            showingThinkingOverlay = false
        }
        
        do {
            let events = try await scheduleService.generateSchedule(
                user: user,
                history: userHistory ?? UserHistory(),
                userNote: userNote
            )
            
            // Save as backup
            scheduleService.saveScheduleBackup(events: events)
            
            // Save to user's currentSchedule and Firebase
            self.user?.currentSchedule = events
            
            // Save to Firebase
            do {
                try await scheduleService.saveScheduleToFirebase(events: events)
            } catch {
                Logger.warning("⚠️ Failed to save schedule to Firebase: \(error.localizedDescription)", category: .schedule)
                // Continue anyway, as we have it locally
            }
            
            // Save today's updated schedule to history
            await historyService.saveTodaysScheduleToHistory(user: user)
            
            return events
        } catch {
            Logger.error("Schedule generation failed: \(error.localizedDescription)", category: .schedule)
            throw error
        }
    }
    
    func updateScheduleWithAI(userMessage: String, currentEvents: [Event]) async throws -> [Event] {
        guard let user = user else {
            throw NSError(domain: "ContentModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "No user found"])
        }
        
        guard creditsService.hasCreditsRemaining() else {
            throw NSError(domain: "ContentModel", code: 429, userInfo: [NSLocalizedDescriptionKey: "No credits remaining"])
        }
        
        // Use a credit
        _ = creditsService.useCredit()
        
        let completeSchedule = try await scheduleService.updateScheduleWithAI(
            user: user,
            history: userHistory ?? UserHistory(),
            userMessage: userMessage,
            currentEvents: currentEvents
        )
        
        self.user?.currentSchedule = completeSchedule
        
        // Save to Firebase
        try await scheduleService.saveScheduleToFirebase(events: completeSchedule)
        
        // Save updated schedule to history
        await historyService.saveTodaysScheduleToHistory(user: user)
        
        return completeSchedule
    }
    
    func checkForCompletedSchedule() -> [Event]? {
        return scheduleService.checkForCompletedSchedule(userSchedule: user?.currentSchedule ?? [])
    }
    
    func isGeneratingInBackground() -> Bool {
        return scheduleService.isGeneratingInBackground()
    }
    
    func clearAllScheduleData() {
        user?.currentSchedule = []
        scheduleService.clearAllScheduleData()
    }
    
    func checkForBackgroundGenerationOnStartup() {
        // Check if generation was happening when app went to background
        if UserDefaults.standard.bool(forKey: UserDefaultsKeys.isGeneratingSchedule) {
            isGeneratingSchedule = true
            showingThinkingOverlay = true
            
            // Start monitoring for completion
            monitorBackgroundGeneration()
        }
    }
    
    private func monitorBackgroundGeneration() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            Task { @MainActor in
                if !self.isGeneratingInBackground() {
                    timer.invalidate()
                    self.isGeneratingSchedule = false
                    self.showingThinkingOverlay = false
                    
                    // Try to load completed schedule
                    if let completedEvents = self.checkForCompletedSchedule() {
                        self.user?.currentSchedule = completedEvents
                        
                        Task {
                            try? await self.saveUserInfo()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Auto-Scheduling
    
    func setupAutoScheduling() async {
        guard let user = user else { return }
        await autoSchedulingService.setupAutoScheduling(user: user)
        await setupNotifications()
    }
    
    func toggleAutoScheduling(_ enabled: Bool) {
        autoSchedulingService.toggleAutoScheduling(enabled, user: user)
    }
    
    func isAutoSchedulingEnabled() -> Bool {
        return autoSchedulingService.isAutoSchedulingEnabled()
    }
    
    func checkAndOfferScheduleGeneration() async {
        guard let user = user else { return }
        await autoSchedulingService.checkAndOfferScheduleGeneration(
            user: user,
            scheduleService: scheduleService
        )
    }
    
    // MARK: - Notifications
    
    func setupNotifications() async {
        // Request permissions
        let granted = await NotificationManager.shared.requestPermissions()
        if granted {
            NotificationManager.shared.setupNotificationCategories()
            await scheduleUserNotifications()
        }
    }
    
    func scheduleUserNotifications() async {
        guard let user = user else { return }
        
        let wakeTime = user.todaysAwakeHours?.wakeTime ?? user.awakeHours.wakeTime
        let sleepTime = user.todaysAwakeHours?.sleepTime ?? user.awakeHours.sleepTime
        
        await NotificationManager.shared.scheduleDailyNotifications(
            wakeTime: wakeTime,
            sleepTime: sleepTime
        )
        
        Logger.info("✅ Scheduled daily notifications - Wake: \(wakeTime), Sleep: \(sleepTime)", category: .notifications)
    }
    
    func checkForDayCompletion() async {
        guard let user = user else { return }
        await historyService.checkForDayCompletion(user: user)
    }
    
    // MARK: - Credits Management
    
    func checkAndResetCreditsIfNeeded() {
        creditsService.checkAndResetCreditsIfNeeded()
    }
    
    func useCredit() -> Bool {
        return creditsService.useCredit()
    }
    
    func hasCreditsRemaining() -> Bool {
        return creditsService.hasCreditsRemaining()
    }
    
    func resetCreditsForTesting() {
        creditsService.resetCreditsForTesting()
    }
    
    // MARK: - History Management
    
    func fetchUserHistory() async throws {
        try await historyService.fetchUserHistory()
    }
    
    func saveTodaysScheduleToHistory() async {
        guard let user = user else { return }
        await historyService.saveTodaysScheduleToHistory(user: user)
    }
    
    func archiveTodaysSchedule() async throws {
        guard let user = user else { return }
        try await historyService.archiveTodaysSchedule(user: user)
    }
    
    func clearTodaysScheduleForNewDay() async throws {
        guard var user = user else { return }
        try await historyService.clearTodaysScheduleForNewDay(user: &user)
        self.user = user
        try await saveUserInfo()
    }
    
    func checkForNewDay() async {
        guard let user = user else { return }
        await historyService.checkForNewDay(user: user)
    }
    
    // MARK: - AI Thinking Functions
    
    func generateThinkingStepsForScheduleGeneration() -> [String] {
        guard let user = user else {
            return [
                "🤔 Preparing to create your schedule...",
                "📋 Setting up the planning framework...",
                "⏰ Analyzing your time preferences...",
                "✨ Finalizing your schedule..."
            ]
        }
        
        let hasGoals = !user.goals.filter { $0.isActive }.isEmpty
        let hasAssignments = !user.assignments.filter { !$0.completed }.isEmpty
        let hasTests = !user.tests.filter { !$0.prepared }.isEmpty
        let hasCommitments = !user.recurringCommitments.isEmpty
        
        var steps: [String] = []
        
        // Step 1: Always analyze user data
        steps.append("🤔 Analyzing your goals, commitments, and preferences...")
        
        // Step 2: Time analysis
        if hasCommitments {
            steps.append("📅 Reviewing your recurring commitments and time blocks...")
        } else {
            steps.append("⏰ Analyzing your available time windows...")
        }
        
        // Step 3: Priority setting
        if hasAssignments || hasTests {
            steps.append("📚 Prioritizing assignments and test preparation...")
        } else if hasGoals {
            steps.append("🎯 Planning your goal activities and personal time...")
        } else {
            steps.append("⚖️ Balancing your schedule for optimal productivity...")
        }
        
        // Step 4: Schedule building
        steps.append("🏗️ Building your personalized schedule structure...")
        
        // Step 5: Final optimization
        steps.append("✨ Finalizing and optimizing your perfect day...")
        
        return steps
    }
    
    func simulateThinkingProcess() async {
        let thinkingSteps = generateThinkingStepsForScheduleGeneration()
        
        showingThinkingOverlay = true
        thinkingStepIndex = 0
        currentThinkingStep = thinkingSteps.first ?? "Preparing your schedule..."
        
        for (index, step) in thinkingSteps.enumerated() {
            currentThinkingStep = step
            thinkingStepIndex = index
            
            // Add random delay between thinking steps (1.0 to 5.0 seconds)
            let randomDelay = Double.random(in: 1.0...5.0)
            let nanoseconds = UInt64(randomDelay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    }
    
    // MARK: - Debug Helpers
    
    func debugUserState() {
        Logger.debugUserState(
            authUserExists: Auth.auth().currentUser != nil,
            authUID: Auth.auth().currentUser?.uid,
            authEmail: Auth.auth().currentUser?.email,
            loggedIn: loggedIn,
            userModelExists: user != nil,
            userName: user?.name,
            userEmail: user?.email
        )
    }
    
    func debugScheduleState() {
        let schedule = user?.currentSchedule ?? []
        let backupExists = UserDefaults.standard.data(forKey: UserDefaultsKeys.generatedSchedule) != nil
        let backupCount: Int
        if let eventsData = UserDefaults.standard.data(forKey: UserDefaultsKeys.generatedSchedule),
           let events = try? JSONDecoder().decode([Event].self, from: eventsData) {
            backupCount = events.count
        } else {
            backupCount = 0
        }
        
        Logger.debugScheduleState(
            scheduleCount: schedule.count,
            scheduleIsEmpty: schedule.isEmpty,
            eventTitles: schedule.map { $0.title },
            backupExists: backupExists,
            backupCount: backupCount,
            isGenerating: isGeneratingInBackground()
        )
    }
}
