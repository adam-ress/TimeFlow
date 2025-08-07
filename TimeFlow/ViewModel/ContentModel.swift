//
//  ContentModel.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/11/25.
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
    var user: User? = nil
    var userHistory: UserHistory? = nil
    
    var madeTodaySchedule = false
    
    var newUser: Bool? = nil
    
    var loggedIn = false
    var agreedToEULA = true //give them the benefit of the doubt haha :)
    
    // Add UI loading state that persists across views
    var isGeneratingSchedule = false
    
    // AI Thinking feature - Add these new properties
    var showingThinkingOverlay = false
    var currentThinkingStep = ""
    var thinkingStepIndex = 0
    
    // Credits system for AI schedule updates
    var dailyCredits: Int = 6
    private let maxDailyCredits = 6
    private let creditsResetKey = "lastCreditsReset"
    
    private var showAlert: Bool = false
    
    private var email: String = ""
    private var password: String = ""
    private var isSecured: Bool = true
    
    // Add listener for real-time updates
    private var userListener: ListenerRegistration?
    
    let db = Firestore.firestore()
    
    // Serial queue for userHistory operations
    private let historyQueue = DispatchQueue(label: "com.timeflow.userhistory", qos: .utility)
    
    func currentUID() -> String? {
        Auth.auth().currentUser?.uid
    }
    
    func debugUserState() {
        print("🔍 ContentModel Debug:")
        print("  • Auth user exists: \(Auth.auth().currentUser != nil)")
        print("  • Auth user UID: \(Auth.auth().currentUser?.uid ?? "nil")")
        print("  • Auth user email: \(Auth.auth().currentUser?.email ?? "nil")")
        print("  • loggedIn flag: \(loggedIn)")
        print("  • user model exists: \(user != nil)")
        print("  • user model name: \(user?.name ?? "nil")")
        print("  • user model email: \(user?.email ?? "nil")")
    }
    
    func checkLogin() {
        let wasLoggedIn = loggedIn
        loggedIn = Auth.auth().currentUser != nil
        
        print("🔍 CheckLogin called:")
        print("  • Was logged in: \(wasLoggedIn)")
        print("  • Now logged in: \(loggedIn)")
        
        // If newly logged in and no user data, try to fetch
        if loggedIn && user == nil {
            print("🔄 Logged in but no user data, fetching...")
            Task {
                do {
                    try await fetchUser()
                    print("✅ User data fetched successfully")
                    // Reset credits if needed after login
                    checkAndResetCreditsIfNeeded()
                    // Save today's schedule to history
                    await saveTodaysScheduleToHistory()
                    // Check if we need to generate today's schedule
                    await checkAndOfferScheduleGeneration()
                } catch {
                    print("❌ Failed to fetch user data: \(error)")
                }
            }
        } else if loggedIn {
            // User already logged in, just check credits and schedule
            checkAndResetCreditsIfNeeded()
            Task {
                // Save today's schedule to history on app open
                await saveTodaysScheduleToHistory()
                await checkAndOfferScheduleGeneration()
            }
        }
    }
    
    func onboardingComplete() async throws {
        guard let uid = currentUID() else { return }

        try await db
            .collection("users")
            .document(uid)
            .updateData(["new_user": false])
            
        self.newUser = false
    }
    
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
        checkLogin()
        try await fetchUser()
        setupUserListener()
        await setupAutoScheduling()
    }
    
    // get user!!
    func fetchUser() async throws {
        print("🔄 Fetching user data...")
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ContentModel", code: 401,
                          userInfo: [NSLocalizedDescriptionKey : "Not signed in"])
        }

        let snapshot = try await db
            .collection("users")
            .document(uid)
            .getDocument()

        guard snapshot.exists else { 
            print("❌ User document does not exist")
            return 
        }

        print("✅ User document found, decoding...")

        do {
            user = try snapshot.data(as: User.self)
            print("✅ User decoded successfully with \(user?.currentSchedule.count ?? 0) events")
        } catch {
            print("❌ Failed to decode user with Codable: \(error)")
            throw error
        }
        
        // Ensure name and email are properly populated from the database
        if let name = snapshot.get("name") as? String {
            user?.name = name
        }
        if let email = snapshot.get("email") as? String {
            user?.email = email
        }
        
        print("✅ User fetch complete - currentSchedule has \(self.user?.currentSchedule.count ?? 0) events")
        
        // Save backup of the successfully decoded schedule
        if let events = user?.currentSchedule, !events.isEmpty {
            saveScheduleBackup(events: events)
        }
        
        // Set up listener if not already done
        if userListener == nil {
            setupUserListener()
        }
        
        // Fetch user history for analytics
        do {
            try await fetchUserHistory()
        } catch {
            print("⚠️ Failed to fetch user history: \(error)")
        }
        
        // Schedule notifications with user's wake/sleep times
        await scheduleUserNotifications()
    }
    
    func saveUserInfo() async throws {
        user?.email = Auth.auth().currentUser?.email ?? ""
        user?.name = Auth.auth().currentUser?.displayName ?? ""
        
        guard let uid = currentUID(), let userData = user else { return }
        try db.collection("users").document(uid).setData(from: userData, merge: true)
    }
    
    func googleSignIn(windowScene: UIWindowScene?) async throws {
        guard let rootVC = windowScene?.windows.first?.rootViewController else {
            throw URLError(.badServerResponse)
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw URLError(.badServerResponse)
        }
        
        let accessToken = result.user.accessToken.tokenString
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        
        let authResult = try await Auth.auth().signIn(with: credential)
        let authUser = authResult.user
        
        if authResult.additionalUserInfo?.isNewUser == true {
            let doc = db.collection("users").document(authUser.uid)
            
            try await doc.setData([
                "email": authUser.email ?? "",
                "name": authUser.displayName ?? "",
                "new_user": true,
                "accountCreated": Timestamp(date: Date()),
                "agreedToEULA": false
            ])
        }
        checkLogin()
        try await fetchUser()
        setupUserListener()
        await setupAutoScheduling()
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        loggedIn = false
        user = nil
        checkLogin()
    }
    
    func createAccount(email: String, name: String, password: String) async throws {
        
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        
        try await db
            .collection("users")
            .document(result.user.uid)
            .setData([
                "email": email,
                "name": name,
                "new_user": true,
                "accountCreated": Timestamp(date: Date()),
                "agreedToEULA": false
            ])
        checkLogin()
        try await fetchUser()
        setupUserListener()
        await setupAutoScheduling()
    }
    
    
    func checkIfEmailExists(email: String, completion: @escaping (Bool, Error?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: "TemporaryPassword123") { authResult, error in
            if let error = error as NSError? {
                // Check if the error indicates the email is already in use
                if error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    completion(true, nil) // Email exists
                } else {
                    completion(false, error) // Other error (e.g., invalid email, network issue)
                }
            } else {
                // User was created successfully, but we don't want a new user
                // Delete the temporary user to avoid cluttering Firebase
                if let user = authResult?.user {
                    user.delete { deletionError in
                        if let deletionError = deletionError {
                            print("Failed to delete temporary user: \(deletionError.localizedDescription)")
                        }
                        completion(false, nil) // Email does not exist
                    }
                } else {
                    completion(false, nil) // Email does not exist
                }
            }
        }
    }
    
    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("✅ Password reset email sent to \(email)")
        } catch {
            print("❌ Failed to send password reset email: \(error)")
            throw error
        }
    }
    
    func checkNewUser() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw URLError(.userAuthenticationRequired)
        }

        // Firestore fetch runs on a background thread
        let snapshot = try await db
            .collection("users")
            .document(uid)
            .getDocument()

        let flag = snapshot.get("new_user") as? Bool ?? false
        self.newUser = flag                              // safe: already on MainActor
    }
    
    
    
    //Schedule made for today?-related functions
    
    ////"HH:mm" (24-hour) → Date *today* at that time.
    /// Returns `nil` if the string is malformed (e.g. "25:90").
    private func today(at hhmm: String) -> Date? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), (0...23).contains(h),
              let m = Int(parts[1]), (0...59).contains(m)
        else { return nil }

        var dc = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dc.hour = h
        dc.minute = m
        return Calendar.current.date(from: dc)
    }
    
    func hasMadeSchedule(wakeHHMM: String, markDone: Bool = false) -> Bool {

        let key = "lastScheduleMade"
        let now = Date()
        guard let wakeToday = today(at: wakeHHMM) else { return false }

        let windowStart = Calendar.current.date(byAdding: .hour, value: -3, to: wakeToday)!
       
        let windowEnd = windowStart > now
            ? wakeToday
            : Calendar.current.date(byAdding: .day, value: 1, to: windowStart)!

        if markDone { UserDefaults.standard.set(now, forKey: key) }

        if let saved = UserDefaults.standard.object(forKey: key) as? Date {
            return saved >= windowStart && saved < windowEnd
        }
        return false
    }
    
    //------------------------------ Generate Schedule In Background -------------------------------------
    
    func generateScheduleWithBackgroundSupport(userNote: String = "") async throws -> [Event] {
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
            UserDefaults.standard.set(userData, forKey: "cachedUserData")
        }
        
        // Store generation state
        UserDefaults.standard.set(true, forKey: "isGeneratingSchedule")
        UserDefaults.standard.set(userNote, forKey: "pendingUserNote")
        UserDefaults.standard.set(Date(), forKey: "generationStartTime")
        
        // Schedule background continuation
        BackgroundTaskManager.shared.scheduleBackgroundTask()
        
        defer {
            BackgroundTaskManager.shared.endBackgroundTask()
            UserDefaults.standard.set(false, forKey: "isGeneratingSchedule")
            UserDefaults.standard.removeObject(forKey: "pendingUserNote")
            // Reset UI loading state and thinking overlay
            isGeneratingSchedule = false
            showingThinkingOverlay = false
        }
        
        guard let user = self.user else {
            throw NSError(domain: "ContentModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "No user found"])
        }
        
        do {
            let events = try await userInfoToSchedule(
                user: user,
                history: self.userHistory ?? UserHistory(),
                note: userNote
            )
            
            // Save as backup
            if let eventsData = try? JSONEncoder().encode(events) {
                UserDefaults.standard.set(eventsData, forKey: "generatedSchedule")
                UserDefaults.standard.set(Date(), forKey: "scheduleGeneratedAt")
                UserDefaults.standard.set(false, forKey: "backupFromFirebase")
            }
            
            // Save to user's currentSchedule and Firebase
            await MainActor.run {
                self.user?.currentSchedule = events
            }
            
            // Save to Firebase
            do {
                try await saveCurrentScheduleToFirebase(events: events)
            } catch {
                print("⚠️ Failed to save schedule to Firebase: \(error)")
                // Continue anyway, as we have it locally
            }
            
            // Save today's updated schedule to history
            await saveTodaysScheduleToHistory()
            
            return events
            
        } catch {
            print("Schedule generation failed: \(error)")
            throw error
        }
    }
    
    private func saveCurrentScheduleToFirebase(events: [Event]) async throws {
        guard let uid = currentUID() else {
            throw NSError(domain: "ContentModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        
        // Convert events to Firestore-compatible format
        let eventsData = events.map { event in
            var eventData: [String: Any] = [
                "id": event.id.uuidString,
                "start": Timestamp(date: event.start),
                "end": Timestamp(date: event.end),
                "title": event.title,
                "icon": event.icon,
                "eventType": event.eventType.rawValue
            ]
            
            // Only add colorName if it exists
            if let colorName = event.colorName {
                eventData["colorName"] = colorName
            }
            
            return eventData
        }
        
        do {
            try await db
                .collection("users")
                .document(uid)
                .updateData([
                    "currentSchedule": eventsData,
                    "scheduleGeneratedAt": Timestamp(date: Date())
                ])
            print("✅ Successfully saved schedule to Firebase")
        } catch {
            print("❌ Firebase save failed: \(error)")
            throw error
        }
    }
    
    func checkForCompletedSchedule() -> [Event]? {
        // Don't return backup if user explicitly has an empty currentSchedule
        if let user = self.user {
            // User has explicitly set currentSchedule (even if empty) - don't use backup
            return user.currentSchedule.isEmpty ? nil : user.currentSchedule
        }
        
        // Only use backup if user has no currentSchedule field at all
        guard let eventsData = UserDefaults.standard.data(forKey: "generatedSchedule"),
              let events = try? JSONDecoder().decode([Event].self, from: eventsData),
              !events.isEmpty,
              let generatedAt = UserDefaults.standard.object(forKey: "scheduleGeneratedAt") as? Date else {
            return nil
        }
        
        // Consider valid if generated within last 12 hours
        let isRecent = Date().timeIntervalSince(generatedAt) < 12 * 60 * 60
        return isRecent ? events : nil
    }
    
    func isGeneratingInBackground() -> Bool {
        return UserDefaults.standard.bool(forKey: "isGeneratingSchedule")
    }
    
    func clearAllScheduleData() {
        // Clear local user model
        user?.currentSchedule = []
        
        // Clear UserDefaults backup
        UserDefaults.standard.removeObject(forKey: "generatedSchedule")
        UserDefaults.standard.removeObject(forKey: "scheduleGeneratedAt")
        UserDefaults.standard.removeObject(forKey: "cachedUserData")
        UserDefaults.standard.removeObject(forKey: "backupFromFirebase")
        UserDefaults.standard.set(false, forKey: "isGeneratingSchedule")
        
        print("🧹 Cleared all local schedule data")
    }
    
    func logScheduleDataSources() {
        print("📊 Schedule Data Sources:")
        print("• User.currentSchedule: \(user?.currentSchedule.count ?? 0) events")
        
        if UserDefaults.standard.data(forKey: "generatedSchedule") != nil {
            print("• UserDefaults backup: EXISTS")
        } else {
            print("• UserDefaults backup: NONE")
        }
        
        print("• Background generating: \(isGeneratingInBackground())")
    }
    
    func debugScheduleState() {
        print("🔍 Schedule Debug State:")
        if let schedule = user?.currentSchedule {
            print("  • User.currentSchedule: \(schedule.count) events")
            if schedule.isEmpty {
                print("    ↳ Schedule exists but is EMPTY")
            } else {
                print("    ↳ Events: \(schedule.map { $0.title }.joined(separator: ", "))")
            }
        } else {
            print("  • User.currentSchedule: nil")
        }
        
        if let eventsData = UserDefaults.standard.data(forKey: "generatedSchedule"),
           let events = try? JSONDecoder().decode([Event].self, from: eventsData) {
            print("  • UserDefaults backup: \(events.count) events")
        } else {
            print("  • UserDefaults backup: none")
        }
        
        print("  • Background generating: \(isGeneratingInBackground())")
    }
    
    func refreshUserData() async throws {
        print("🔄 Refreshing user data...")
        guard let uid = currentUID() else {
            throw NSError(domain: "ContentModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }

        let snapshot = try await db
            .collection("users")
            .document(uid)
            .getDocument()

        guard snapshot.exists else { 
            print("❌ User document does not exist")
            return 
        }

        print("✅ User document found, decoding...")
        
        do {
            user = try snapshot.data(as: User.self)
            print("✅ User refreshed successfully with \(user?.currentSchedule.count ?? 0) events")
        } catch {
            print("❌ Failed to decode user during refresh: \(error)")
            throw error
        }
        
        // Ensure name and email are properly populated from the database
        if let name = snapshot.get("name") as? String {
            user?.name = name
        }
        if let email = snapshot.get("email") as? String {
            user?.email = email
        }
        
        print("✅ User data refresh complete - currentSchedule has \(self.user?.currentSchedule.count ?? 0) events")
        
        // Save backup of the successfully decoded schedule
        if let events = user?.currentSchedule, !events.isEmpty {
            saveScheduleBackup(events: events, isFromFirebase: true)
        }
        
        // Re-schedule notifications with updated user data
        await scheduleUserNotifications()
    }
    
    private func saveScheduleBackup(events: [Event], isFromFirebase: Bool = false) {
        if let eventsData = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(eventsData, forKey: "generatedSchedule")
            UserDefaults.standard.set(Date(), forKey: "scheduleGeneratedAt")
            UserDefaults.standard.set(isFromFirebase, forKey: "backupFromFirebase")
        }
    }
    
    func setupUserListener() {
        guard let uid = currentUID() else { return }
        
        // Remove existing listener if any
        userListener?.remove()
        
        // Set up new listener for user document changes
        userListener = db.collection("users").document(uid).addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ User listener error: \(error)")
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else { return }
                
                do {
                    print("🔄 User listener triggered - decoding updated user data")
                    let updatedUser = try snapshot.data(as: User.self)
                    
                    // Ensure name and email are properly populated from the database
                    var finalUser = updatedUser
                    finalUser.name = snapshot.get("name") as? String ?? updatedUser.name
                    finalUser.email = snapshot.get("email") as? String ?? updatedUser.email
                    
                    // Always update to match Firebase exactly
                    self.user = finalUser
                    
                    print("✅ User listener update complete - currentSchedule has \(self.user?.currentSchedule.count ?? 0) events")
                    
                    // Save backup AFTER updating user, and mark as Firebase-sourced
                    if !finalUser.currentSchedule.isEmpty {
                        self.saveScheduleBackup(events: finalUser.currentSchedule, isFromFirebase: true)
                    }
                    
                } catch {
                    print("❌ Error decoding user update: \(error)")
                }
            }
        }
    }
    
    func setupAutoScheduling() async {
        guard let user = self.user else { return }
        
        // Set default auto-schedule to enabled
        if !UserDefaults.standard.bool(forKey: "hasSetAutoSchedule") {
            UserDefaults.standard.set(true, forKey: "autoScheduleEnabled")
            UserDefaults.standard.set(true, forKey: "hasSetAutoSchedule")
        }
        
        // Schedule wake-up generation if auto-scheduling is enabled
        if UserDefaults.standard.bool(forKey: "autoScheduleEnabled") {
            let wakeTime = user.todaysAwakeHours?.wakeTime ?? user.awakeHours.wakeTime
            BackgroundTaskManager.shared.scheduleWakeUpGeneration(wakeUpTime: wakeTime)
            
            // Cache user data for background generation
            if let userData = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(userData, forKey: "cachedUserData")
            }
        }
        
        // Set up notifications
        await setupNotifications()
    }

    func setupNotifications() async {
        // Request permissions
        let granted = await NotificationManager.shared.requestPermissions()
        if granted {
            NotificationManager.shared.setupNotificationCategories()
            
            // Schedule daily notifications with user's wake/sleep times
            await scheduleUserNotifications()
        }
    }
    
    func scheduleUserNotifications() async {
        guard let user = self.user else { return }
        
        let wakeTime = user.todaysAwakeHours?.wakeTime ?? user.awakeHours.wakeTime
        let sleepTime = user.todaysAwakeHours?.sleepTime ?? user.awakeHours.sleepTime
        
        await NotificationManager.shared.scheduleDailyNotifications(
            wakeTime: wakeTime,
            sleepTime: sleepTime
        )
        
        print("✅ Scheduled daily notifications - Wake: \(wakeTime), Sleep: \(sleepTime)")
    }

    func checkForDayCompletion() async {
        guard let user = self.user else { return }
        
        let now = Date()
        let remainingEvents = user.currentSchedule.filter { event in
            event.start > now && !event.title.contains("NGTime")
        }
        
        // Day completion logic without notification since we simplified notifications
        if remainingEvents.isEmpty && !user.currentSchedule.isEmpty {
            print("🎉 User has completed their daily schedule!")
            // Could potentially trigger other completion logic here in the future
        }
    }
    
    func toggleAutoScheduling(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "autoScheduleEnabled")
        
        if enabled {
            // Enable auto-scheduling
            if let user = self.user {
                let wakeTime = user.todaysAwakeHours?.wakeTime ?? user.awakeHours.wakeTime
                BackgroundTaskManager.shared.scheduleWakeUpGeneration(wakeUpTime: wakeTime)
                
                // Cache user data
                if let userData = try? JSONEncoder().encode(user) {
                    UserDefaults.standard.set(userData, forKey: "cachedUserData")
                }
            }
        } else {
            // Disable auto-scheduling
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.timeflow.wakeupschedule")
        }
    }

    func isAutoSchedulingEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "autoScheduleEnabled")
    }
    
    func checkForBackgroundGenerationOnStartup() {
        // Check if generation was happening when app went to background
        if UserDefaults.standard.bool(forKey: "isGeneratingSchedule") {
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
    
    // MARK: - Credits Management
    
    func checkAndResetCreditsIfNeeded() {
        // Temporarily force to 6 for testing
        dailyCredits = maxDailyCredits
        UserDefaults.standard.set(dailyCredits, forKey: "dailyCredits")
        return
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastReset = UserDefaults.standard.object(forKey: creditsResetKey) as? Date {
            let lastResetDay = calendar.startOfDay(for: lastReset)
            
            // If it's a new day, reset credits
            if today > lastResetDay {
                dailyCredits = maxDailyCredits
                UserDefaults.standard.set(Date(), forKey: creditsResetKey)
                print("🔄 Credits reset to \(maxDailyCredits) for new day")
            } else {
                // Load saved credits for today
                dailyCredits = UserDefaults.standard.object(forKey: "dailyCredits") as? Int ?? maxDailyCredits
            }
        } else {
            // First time setup
            dailyCredits = maxDailyCredits
            UserDefaults.standard.set(Date(), forKey: creditsResetKey)
        }
    }
    
    func useCredit() -> Bool {
        guard dailyCredits > 0 else { return false }
        
        dailyCredits -= 1
        UserDefaults.standard.set(dailyCredits, forKey: "dailyCredits")
        print("💳 Used credit. Remaining: \(dailyCredits)")
        return true
    }
    
    func hasCreditsRemaining() -> Bool {
        return dailyCredits > 0
    }
    
    // MARK: - Testing Helper
    func resetCreditsForTesting() {
        dailyCredits = maxDailyCredits
        UserDefaults.standard.set(dailyCredits, forKey: "dailyCredits")
        UserDefaults.standard.set(Date(), forKey: creditsResetKey)
        print("🔄 Credits manually reset to \(maxDailyCredits) for testing")
    }
    
    // MARK: - AI Schedule Update
    
    func updateScheduleWithAI(userMessage: String, currentEvents: [Event]) async throws -> [Event] {
        guard let user = self.user else {
            throw NSError(domain: "ContentModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "No user found"])
        }
        
        guard hasCreditsRemaining() else {
            throw NSError(domain: "ContentModel", code: 429, userInfo: [NSLocalizedDescriptionKey: "No credits remaining"])
        }
        
        // Use a credit
        _ = useCredit()
        
        // Filter to only current and future events (no NGTimes, no past events)
        let now = Date()
        let futureEvents = currentEvents.filter { event in
            event.end > now && !event.title.contains("NGTime")
        }
        
        // Create simple, direct prompt with current schedule
        let scheduleContext = futureEvents.map { event in
            let startTime = event.start.hhmmString
            let endTime = event.end.hhmmString
            return "{\n  \"title\": \"\(event.title)\",\n  \"start\": \"\(startTime)\",\n  \"end\": \"\(endTime)\",\n  \"id\": \"\(event.id.uuidString)\"\n}"
        }.joined(separator: ",\n")
        
        let currentScheduleJSON = futureEvents.isEmpty ? "[]" : "[\n\(scheduleContext)\n]"
        
        // Create enhanced prompt that better handles event types
        let prompt = """
        SCHEDULE EDITOR - Current schedule (JSON format):
        \(currentScheduleJSON)

        USER REQUEST: \(userMessage)

        IMPORTANT CONTEXT:
        - If user mentions "assignment", "homework", or "worksheet" - this should be EventType: assignment
        - If user mentions "work" as in job/employment - this should be EventType: work  
        - If user mentions "goal", "exercise", "workout" - this should be EventType: goal
        - If user mentions "test", "exam", "study for test" - this should be EventType: testStudy
        - If user mentions "meal", "lunch", "dinner", "breakfast" - this should be EventType: meal
        - Default to EventType: other for unclear cases

        EDITING RULES:
        1. ONLY modify what the user specifically requested
        2. Keep all other events exactly the same
        3. Use 24-hour time format (HH:mm)
        4. Do NOT add random work meetings or job-related events unless user specifically mentions their job
        5. Preserve all existing event IDs for unchanged events
        6. For new events, create appropriate titles (e.g. "Math Worksheet" not "Work")

        Return ONLY the complete updated JSON array with the same format. No explanations.
        Example format:
        [
          {"title": "Math Worksheet", "start": "14:00", "end": "15:00", "id": "new-uuid"}
        ]
        """
        
        // Call the existing userInfoToSchedule function with the enhanced prompt
        let updatedEvents = try await userInfoToSchedule(
            user: user,
            history: self.userHistory ?? UserHistory(),
            note: prompt
        )
        
        // Filter to only future events to avoid showing past ones or NGTimes
        let filteredUpdatedEvents = updatedEvents.filter { event in
            event.end > now && !event.title.contains("NGTime")
        }
        
        // Update user's current schedule (preserve past events and NGTimes)
        let pastEvents = currentEvents.filter { event in
            event.end <= now || event.title.contains("NGTime")
        }
        let completeSchedule = pastEvents + filteredUpdatedEvents.sorted { $0.start < $1.start }
        
        self.user?.currentSchedule = completeSchedule
        
        // Save to Firebase
        try await saveCurrentScheduleToFirebase(events: completeSchedule)
        
        // Save updated schedule to history
        await saveTodaysScheduleToHistory()
        
        return completeSchedule
    }
    
    // MARK: - Smart Schedule Generation
    
    func checkAndOfferScheduleGeneration() async {
        guard isAutoSchedulingEnabled(), let user = self.user else { return }
        
        let wakeTime = user.todaysAwakeHours?.wakeTime ?? user.awakeHours.wakeTime
        
        // Check if we already have a schedule for today
        if !user.currentSchedule.isEmpty {
            print("✅ Schedule already exists for today")
            return
        }
        
        // Check if we have a recent background-generated schedule
        if let completedEvents = checkForCompletedSchedule(), !completedEvents.isEmpty {
            print("✅ Found background-generated schedule, applying it")
            self.user?.currentSchedule = completedEvents
            try? await saveUserInfo()
            return
        }
        
        // Check if it's close to or past wake-up time and we should auto-generate
        if shouldAutoGenerateSchedule(wakeTime: wakeTime) {
            print("🤖 Auto-generating schedule for today")
            await generateScheduleInBackground()
        }
    }
    
    private func shouldAutoGenerateSchedule(wakeTime: String) -> Bool {
        guard let wakeUpToday = today(at: wakeTime) else { return false }
        
        let now = Date()
        let timeSinceWakeUp = now.timeIntervalSince(wakeUpToday)
        
        // Auto-generate if:
        // 1. It's within 2 hours after wake-up time, OR
        // 2. It's past 9 AM (fallback for late wake-up times)
        let twoHoursAfterWakeUp = timeSinceWakeUp >= 0 && timeSinceWakeUp <= (2 * 60 * 60)
        let past9AM = Calendar.current.component(.hour, from: now) >= 9
        
        return twoHoursAfterWakeUp || past9AM
    }
    
    private func generateScheduleInBackground() async {
        guard !isGeneratingSchedule else { return }
        
        do {
            print("🔄 Generating schedule in background...")
            let events = try await generateScheduleWithBackgroundSupport(userNote: "")
            print("✅ Background schedule generation completed with \(events.count) events")
        } catch {
            print("❌ Background schedule generation failed: \(error)")
        }
    }
    
    // MARK: - Account Management
    
    func deleteUserAccount() async throws {
        guard let uid = currentUID() else {
            throw NSError(domain: "ContentModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        
        // Delete user data from Firestore
        try await db.collection("users").document(uid).delete()
        
        // Delete the Firebase Auth account
        try await Auth.auth().currentUser?.delete()
        
        // Clear local data
        user = nil
        userHistory = nil
        loggedIn = false
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "cachedUserData")
        UserDefaults.standard.removeObject(forKey: "generatedSchedule")
        UserDefaults.standard.removeObject(forKey: "scheduleGeneratedAt")
        UserDefaults.standard.removeObject(forKey: "autoScheduleEnabled")
        UserDefaults.standard.removeObject(forKey: "hasSetAutoSchedule")
        UserDefaults.standard.removeObject(forKey: "notification_morning_enabled")
        UserDefaults.standard.removeObject(forKey: "notification_evening_enabled")
        UserDefaults.standard.removeObject(forKey: "hasSetupNotificationDefaults")
        
        // Cancel all notifications
        NotificationManager.shared.cancelAllNotifications()
        
        print("✅ User account deleted successfully")
    }
    
    // MARK: - Daily Schedule Archiving
    
    func archiveTodaysSchedule() async throws {
        guard let user = self.user, !user.currentSchedule.isEmpty else { return }
        
        let today = Date()
        let dailyLog = DailyInfo(
            date: today,
            events: user.currentSchedule,
            awakeHours: user.todaysAwakeHours ?? user.awakeHours
        )
        
        // Initialize userHistory if needed
        if userHistory == nil {
            userHistory = UserHistory()
        }
        
        guard var history = userHistory else { return }
        
        // Add today's log to history
        history.dailyLogs.append(dailyLog)
        
        // Keep only last 30 days of history
        history.dailyLogs = history.dailyLogs.suffix(30).map { $0 }
        
        // Update the property once at the end
        userHistory = history
        
        // Save to Firebase
        try await saveUserHistoryToFirebase()
        
        print("✅ Archived today's schedule with \(user.currentSchedule.count) events")
    }
    
    func clearTodaysScheduleForNewDay() async throws {
        // Archive current schedule first
        try await archiveTodaysSchedule()
        
        // Clear current schedule for new day
        user?.currentSchedule = []
        
        // Save updated user
        try await saveUserInfo()
        
        print("✅ Cleared today's schedule for new day")
    }
    
    private func saveUserHistoryToFirebase() async throws {
        guard let uid = currentUID(), let history = userHistory else { return }
        
        // Convert userHistory to Firestore format
        let historyData = try JSONEncoder().encode(history)
        let historyDict = try JSONSerialization.jsonObject(with: historyData) as? [String: Any] ?? [:]
        
        try await db
            .collection("users")
            .document(uid)
            .updateData(["userHistory": historyDict])
    }
    
    func fetchUserHistory() async throws {
        guard let uid = currentUID() else { return }
        
        let snapshot = try await db
            .collection("users")
            .document(uid)
            .getDocument()
        
        if let historyData = snapshot.get("userHistory") as? [String: Any],
           let jsonData = try? JSONSerialization.data(withJSONObject: historyData),
           let history = try? JSONDecoder().decode(UserHistory.self, from: jsonData) {
            userHistory = history
            print("✅ Loaded user history with \(history.dailyLogs.count) daily logs")
        } else {
            userHistory = UserHistory()
            print("📝 Initialized empty user history")
        }
    }
    
    func checkForNewDay() async {
        guard let user = self.user else { return }
        
        // Check if we need to archive yesterday's schedule
        let lastScheduleDate = UserDefaults.standard.object(forKey: "lastScheduleDate") as? Date
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastDate = lastScheduleDate {
            let lastDay = Calendar.current.startOfDay(for: lastDate)
            
            // If it's a new day and we had a schedule yesterday
            if today > lastDay && !user.currentSchedule.isEmpty {
                do {
                    try await clearTodaysScheduleForNewDay()
                } catch {
                    print("❌ Failed to archive yesterday's schedule: \(error)")
                }
            }
        }
        
        // Update last schedule date
        UserDefaults.standard.set(Date(), forKey: "lastScheduleDate")
    }
    
    // MARK: - Simple Daily Schedule Tracking
    
    func saveTodaysScheduleToHistory() async {
        guard let user = self.user else { return }
        
        // Initialize userHistory if needed
        if userHistory == nil {
            userHistory = UserHistory()
        }
        
        guard var history = userHistory else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        // Find existing entry for today
        if let existingIndex = history.dailyLogs.firstIndex(where: { 
            Calendar.current.startOfDay(for: $0.date) == today 
        }) {
            // Update existing entry for today
            history.dailyLogs[existingIndex] = DailyInfo(
                date: Date(),
                events: user.currentSchedule,
                awakeHours: user.todaysAwakeHours ?? user.awakeHours
            )
            print("✅ Updated today's schedule in history (\(user.currentSchedule.count) events)")
        } else {
            // Add new entry for today
            let dailyLog = DailyInfo(
                date: Date(),
                events: user.currentSchedule,
                awakeHours: user.todaysAwakeHours ?? user.awakeHours
            )
            history.dailyLogs.append(dailyLog)
            print("✅ Added today's schedule to history (\(user.currentSchedule.count) events)")
        }
        
        // Keep only last 30 days
        history.dailyLogs = history.dailyLogs.suffix(30).map { $0 }
        
        // Update the property once at the end
        userHistory = history
        
        // Try to save to Firebase (but don't fail if it doesn't work)
        do {
            try await saveUserHistoryToFirebase()
        } catch {
            print("⚠️ Failed to save history to Firebase (will retry later): \(error)")
        }
    }
    
    // MARK: - AI Thinking Functions
    func generateThinkingStepsForScheduleGeneration() -> [String] {
        guard let user = self.user else {
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
        
        await MainActor.run {
            showingThinkingOverlay = true
            thinkingStepIndex = 0
            currentThinkingStep = thinkingSteps.first ?? "Preparing your schedule..."
        }
        
        for (index, step) in thinkingSteps.enumerated() {
            await MainActor.run {
                currentThinkingStep = step
                thinkingStepIndex = index
            }
            
            // Add random delay between thinking steps (1.0 to 5.0 seconds)
            let randomDelay = Double.random(in: 1.0...5.0)
            let nanoseconds = UInt64(randomDelay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    }
}

// MARK: - DateFormatter Extensions
private extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}