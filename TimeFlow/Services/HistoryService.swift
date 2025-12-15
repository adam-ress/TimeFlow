//
//  HistoryService.swift
//  TimeFlow
//
//  Created during code cleanup
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

/// Service responsible for managing user history and daily schedule archiving
@MainActor
class HistoryService: ObservableObject {
    @Published var userHistory: UserHistory? = nil
    
    let db = Firestore.firestore()
    
    // MARK: - History Management
    
    func fetchUserHistory() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let snapshot = try await db
            .collection("users")
            .document(uid)
            .getDocument()
        
        if let historyData = snapshot.get("userHistory") as? [String: Any],
           let jsonData = try? JSONSerialization.data(withJSONObject: historyData),
           let history = try? JSONDecoder().decode(UserHistory.self, from: jsonData) {
            userHistory = history
            Logger.info("✅ Loaded user history with \(history.dailyLogs.count) daily logs", category: .history)
        } else {
            userHistory = UserHistory()
            Logger.info("📝 Initialized empty user history", category: .history)
        }
    }
    
    func saveTodaysScheduleToHistory(user: User) async {
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
            Logger.info("✅ Updated today's schedule in history (\(user.currentSchedule.count) events)", category: .history)
        } else {
            // Add new entry for today
            let dailyLog = DailyInfo(
                date: Date(),
                events: user.currentSchedule,
                awakeHours: user.todaysAwakeHours ?? user.awakeHours
            )
            history.dailyLogs.append(dailyLog)
            Logger.info("✅ Added today's schedule to history (\(user.currentSchedule.count) events)", category: .history)
        }
        
        // Keep only last 30 days
        history.dailyLogs = history.dailyLogs.suffix(AppConfiguration.History.maxDailyLogs).map { $0 }
        
        // Update the property once at the end
        userHistory = history
        
        // Try to save to Firebase (but don't fail if it doesn't work)
        do {
            try await saveUserHistoryToFirebase()
        } catch {
            Logger.warning("⚠️ Failed to save history to Firebase (will retry later): \(error.localizedDescription)", category: .history)
        }
    }
    
    func archiveTodaysSchedule(user: User) async throws {
        guard !user.currentSchedule.isEmpty else { return }
        
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
        history.dailyLogs = history.dailyLogs.suffix(AppConfiguration.History.maxDailyLogs).map { $0 }
        
        // Update the property once at the end
        userHistory = history
        
        // Save to Firebase
        try await saveUserHistoryToFirebase()
        
        Logger.info("✅ Archived today's schedule with \(user.currentSchedule.count) events", category: .history)
    }
    
    func clearTodaysScheduleForNewDay(user: inout User) async throws {
        // Archive current schedule first
        try await archiveTodaysSchedule(user: user)
        
        // Clear current schedule for new day
        user.currentSchedule = []
        
        Logger.info("✅ Cleared today's schedule for new day", category: .history)
    }
    
    func checkForNewDay(user: User) async {
        // Check if we need to archive yesterday's schedule
        let lastScheduleDate = UserDefaults.standard.object(forKey: UserDefaultsKeys.lastScheduleDate) as? Date
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastDate = lastScheduleDate {
            let lastDay = Calendar.current.startOfDay(for: lastDate)
            
            // If it's a new day and we had a schedule yesterday
            if today > lastDay && !user.currentSchedule.isEmpty {
                do {
                    var mutableUser = user
                    try await clearTodaysScheduleForNewDay(user: &mutableUser)
                } catch {
                    Logger.error("❌ Failed to archive yesterday's schedule: \(error.localizedDescription)", category: .history)
                }
            }
        }
        
        // Update last schedule date
        UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.lastScheduleDate)
    }
    
    func checkForDayCompletion(user: User) async {
        let now = Date()
        let remainingEvents = user.currentSchedule.filter { event in
            event.start > now && !event.title.contains("NGTime")
        }
        
        // Day completion logic without notification since we simplified notifications
        if remainingEvents.isEmpty && !user.currentSchedule.isEmpty {
            Logger.info("🎉 User has completed their daily schedule!", category: .history)
            // Could potentially trigger other completion logic here in the future
        }
    }
    
    // MARK: - Firebase Persistence
    
    private func saveUserHistoryToFirebase() async throws {
        guard let uid = Auth.auth().currentUser?.uid, let history = userHistory else { return }
        
        // Convert userHistory to Firestore format
        let historyData = try JSONEncoder().encode(history)
        let historyDict = try JSONSerialization.jsonObject(with: historyData) as? [String: Any] ?? [:]
        
        try await db
            .collection("users")
            .document(uid)
            .updateData(["userHistory": historyDict])
    }
}

