//
//  ScheduleService.swift
//  TimeFlow
//
//  Created during code cleanup
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

/// Service responsible for schedule generation and management
@MainActor
class ScheduleService: ObservableObject {
    let db = Firestore.firestore()
    private let preprocessor = SchedulePreprocessor()
    private let optimizer = ScheduleOptimizer()
    
    // MARK: - Schedule Generation
    
    func generateSchedule(
        user: User,
        history: UserHistory,
        userNote: String = ""
    ) async throws -> [Event] {
        let now = Date()
        
        // Step 1: Preprocess - analyze tasks, find time slots, calculate priorities
        Logger.info("🔍 Preprocessing schedule data...", category: .schedule)
        let preprocessingResult = preprocessor.preprocess(user: user, now: now)
        
        // Step 2: Generate schedule with AI (using enhanced prompt with algorithmic context)
        Logger.info("🤖 Generating schedule with AI...", category: .schedule)
        let events = try await userInfoToSchedule(
            user: user,
            history: history,
            note: userNote,
            now: now,
            preprocessingResult: preprocessingResult
        )
        
        // Step 3: Post-process - validate, optimize, and score
        Logger.info("✨ Optimizing and validating schedule...", category: .schedule)
        let optimizationResult = optimizer.optimize(events: events, user: user, now: now)
        
        // Log quality metrics
        if optimizationResult.quality.score < 0.7 {
            Logger.warning("⚠️ Schedule quality score: \(Int(optimizationResult.quality.score * 100))%", category: .schedule)
            if !optimizationResult.quality.issues.isEmpty {
                Logger.warning("Issues: \(optimizationResult.quality.issues.joined(separator: "; "))", category: .schedule)
            }
        } else {
            Logger.info("✅ Schedule quality score: \(Int(optimizationResult.quality.score * 100))%", category: .schedule)
        }
        
        if optimizationResult.wasOptimized {
            Logger.info("🔧 Schedule was optimized during post-processing", category: .schedule)
        }
        
        return optimizationResult.events
    }
    
    func updateScheduleWithAI(
        user: User,
        history: UserHistory,
        userMessage: String,
        currentEvents: [Event]
    ) async throws -> [Event] {
        let now = Date()
        
        // Filter to only current and future events (no NGTimes, no past events)
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
            history: history,
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
        
        return completeSchedule
    }
    
    // MARK: - Schedule Persistence
    
    func saveScheduleToFirebase(events: [Event]) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ScheduleService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey : "Not signed in"])
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
            Logger.info("✅ Successfully saved schedule to Firebase", category: .schedule)
        } catch {
            Logger.error("❌ Firebase save failed: \(error.localizedDescription)", category: .schedule)
            throw error
        }
    }
    
    // MARK: - Schedule Backup Management
    
    func saveScheduleBackup(events: [Event], isFromFirebase: Bool = false) {
        if let eventsData = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(eventsData, forKey: UserDefaultsKeys.generatedSchedule)
            UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.scheduleGeneratedAt)
            UserDefaults.standard.set(isFromFirebase, forKey: UserDefaultsKeys.backupFromFirebase)
        }
    }
    
    func checkForCompletedSchedule(userSchedule: [Event]) -> [Event]? {
        // Don't return backup if user explicitly has an empty currentSchedule
        if !userSchedule.isEmpty {
            // User has explicitly set currentSchedule (even if empty) - don't use backup
            return userSchedule.isEmpty ? nil : userSchedule
        }
        
        // Only use backup if user has no currentSchedule field at all
        guard let eventsData = UserDefaults.standard.data(forKey: UserDefaultsKeys.generatedSchedule),
              let events = try? JSONDecoder().decode([Event].self, from: eventsData),
              !events.isEmpty,
              let generatedAt = UserDefaults.standard.object(forKey: UserDefaultsKeys.scheduleGeneratedAt) as? Date else {
            return nil
        }
        
        // Consider valid if generated within last 12 hours
        let isRecent = Date().timeIntervalSince(generatedAt) < Double(AppConstants.scheduleValidHours * 60 * 60)
        return isRecent ? events : nil
    }
    
    func clearAllScheduleData() {
        // Clear UserDefaults backup
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.generatedSchedule)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.scheduleGeneratedAt)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.cachedUserData)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.backupFromFirebase)
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.isGeneratingSchedule)
        
        Logger.info("🧹 Cleared all local schedule data", category: .schedule)
    }
    
    func isGeneratingInBackground() -> Bool {
        return UserDefaults.standard.bool(forKey: UserDefaultsKeys.isGeneratingSchedule)
    }
    
    // MARK: - Schedule Validation
    
    func hasMadeSchedule(wakeHHMM: String, markDone: Bool = false) -> Bool {
        let key = UserDefaultsKeys.lastScheduleMade
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
    
    // MARK: - Helpers
    
    /// "HH:mm" (24-hour) → Date *today* at that time.
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
}

