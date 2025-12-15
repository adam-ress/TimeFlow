//
//  Logger.swift
//  TimeFlow
//
//  Created during code cleanup
//

import Foundation
import os.log

/// Centralized logging utility to replace print statements
enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.timeflow"
    
    // MARK: - Category Loggers
    
    private static let general = OSLog(subsystem: subsystem, category: "general")
    private static let auth = OSLog(subsystem: subsystem, category: "authentication")
    private static let schedule = OSLog(subsystem: subsystem, category: "schedule")
    private static let credits = OSLog(subsystem: subsystem, category: "credits")
    private static let history = OSLog(subsystem: subsystem, category: "history")
    private static let notifications = OSLog(subsystem: subsystem, category: "notifications")
    private static let background = OSLog(subsystem: subsystem, category: "background")
    
    // MARK: - Logging Methods
    
    static func debug(_ message: String, category: Category = .general) {
        log(message, level: .debug, category: category)
    }
    
    static func info(_ message: String, category: Category = .general) {
        log(message, level: .info, category: category)
    }
    
    static func warning(_ message: String, category: Category = .general) {
        log(message, level: .default, category: category)
    }
    
    static func error(_ message: String, category: Category = .general) {
        log(message, level: .error, category: category)
    }
    
    // MARK: - Private Implementation
    
    private static func log(_ message: String, level: OSLogType, category: Category) {
        let osLog: OSLog
        switch category {
        case .general: osLog = general
        case .auth: osLog = auth
        case .schedule: osLog = schedule
        case .credits: osLog = credits
        case .history: osLog = history
        case .notifications: osLog = notifications
        case .background: osLog = background
        }
        
        os_log("%{public}@", log: osLog, type: level, message)
    }
    
    // MARK: - Categories
    
    enum Category {
        case general
        case auth
        case schedule
        case credits
        case history
        case notifications
        case background
    }
}

// MARK: - Convenience Extensions

extension Logger {
    /// Log user state debug information
    static func debugUserState(
        authUserExists: Bool,
        authUID: String?,
        authEmail: String?,
        loggedIn: Bool,
        userModelExists: Bool,
        userName: String?,
        userEmail: String?
    ) {
        let message = """
        🔍 ContentModel Debug:
          • Auth user exists: \(authUserExists)
          • Auth user UID: \(authUID ?? "nil")
          • Auth user email: \(authEmail ?? "nil")
          • loggedIn flag: \(loggedIn)
          • user model exists: \(userModelExists)
          • user model name: \(userName ?? "nil")
          • user model email: \(userEmail ?? "nil")
        """
        debug(message, category: .auth)
    }
    
    /// Log schedule state debug information
    static func debugScheduleState(
        scheduleCount: Int,
        scheduleIsEmpty: Bool,
        eventTitles: [String],
        backupExists: Bool,
        backupCount: Int,
        isGenerating: Bool
    ) {
        var message = """
        🔍 Schedule Debug State:
          • User.currentSchedule: \(scheduleCount) events
        """
        
        if scheduleIsEmpty {
            message += "\n    ↳ Schedule exists but is EMPTY"
        } else {
            message += "\n    ↳ Events: \(eventTitles.joined(separator: ", "))"
        }
        
        if backupExists {
            message += "\n  • UserDefaults backup: \(backupCount) events"
        } else {
            message += "\n  • UserDefaults backup: none"
        }
        
        message += "\n  • Background generating: \(isGenerating)"
        
        debug(message, category: .schedule)
    }
}

