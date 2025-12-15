//
//  Constants.swift
//  TimeFlow
//
//  Created during code cleanup
//

import Foundation

/// Centralized constants for UserDefaults keys and app-wide values
enum UserDefaultsKeys {
    // User state
    static let lastScheduleMade = "lastScheduleMade"
    static let lastScheduleDate = "lastScheduleDate"
    static let isGeneratingSchedule = "isGeneratingSchedule"
    static let pendingUserNote = "pendingUserNote"
    static let generationStartTime = "generationStartTime"
    
    // Schedule data
    static let generatedSchedule = "generatedSchedule"
    static let scheduleGeneratedAt = "scheduleGeneratedAt"
    static let backupFromFirebase = "backupFromFirebase"
    static let cachedUserData = "cachedUserData"
    
    // Auto-scheduling
    static let autoScheduleEnabled = "autoScheduleEnabled"
    static let hasSetAutoSchedule = "hasSetAutoSchedule"
    static let savedUserNote = "savedUserNote"
    
    // Credits
    static let dailyCredits = "dailyCredits"
    static let lastCreditsReset = "lastCreditsReset"
    
    // Notifications
    static let notificationMorningEnabled = "notification_morning_enabled"
    static let notificationEveningEnabled = "notification_evening_enabled"
    static let hasSetupNotificationDefaults = "hasSetupNotificationDefaults"
}

/// App-wide configuration constants
enum AppConstants {
    // Credits
    static let maxDailyCredits = 6
    
    // Schedule validation
    static let scheduleValidHours = 12 // Hours a generated schedule is considered valid
    
    // Time windows
    static let autoScheduleWindowHours = 2 // Hours after wake-up to auto-generate
    static let autoScheduleFallbackHour = 9 // Fallback hour (9 AM) for auto-generation
    
    // Background task identifiers
    static let backgroundTaskIdentifier = "com.timeflow.schedulegeneration"
    static let wakeUpScheduleIdentifier = "com.timeflow.wakeupschedule"
    
    // NGTime buffer (minutes before/after fixed commitments)
    static let ngTimeBufferMinutes = 5
    
    // Sleep requirements
    static let minimumSleepHours = 6
    static let minimumSleepHoursCollege = 7
}

