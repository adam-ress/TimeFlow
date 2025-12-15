//
//  CreditsService.swift
//  TimeFlow
//
//  Created during code cleanup
//

import Foundation
import SwiftUI

/// Manages the credits system for AI schedule updates
@MainActor
class CreditsService: ObservableObject {
    @Published var dailyCredits: Int = AppConstants.maxDailyCredits
    
    private let maxDailyCredits = AppConstants.maxDailyCredits
    private let creditsResetKey = UserDefaultsKeys.lastCreditsReset
    
    init() {
        checkAndResetCreditsIfNeeded()
    }
    
    /// Checks if credits need to be reset for a new day and resets if needed
    func checkAndResetCreditsIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastReset = UserDefaults.standard.object(forKey: creditsResetKey) as? Date {
            let lastResetDay = calendar.startOfDay(for: lastReset)
            
            // If it's a new day, reset credits
            if today > lastResetDay {
                dailyCredits = maxDailyCredits
                UserDefaults.standard.set(Date(), forKey: creditsResetKey)
                UserDefaults.standard.set(dailyCredits, forKey: UserDefaultsKeys.dailyCredits)
                Logger.info("🔄 Credits reset to \(maxDailyCredits) for new day", category: .credits)
            } else {
                // Load saved credits for today
                dailyCredits = UserDefaults.standard.object(forKey: UserDefaultsKeys.dailyCredits) as? Int ?? maxDailyCredits
            }
        } else {
            // First time setup
            dailyCredits = maxDailyCredits
            UserDefaults.standard.set(Date(), forKey: creditsResetKey)
            UserDefaults.standard.set(dailyCredits, forKey: UserDefaultsKeys.dailyCredits)
        }
    }
    
    /// Uses one credit and returns true if successful, false if no credits remaining
    func useCredit() -> Bool {
        guard dailyCredits > 0 else { return false }
        
        dailyCredits -= 1
        UserDefaults.standard.set(dailyCredits, forKey: UserDefaultsKeys.dailyCredits)
        Logger.info("💳 Used credit. Remaining: \(dailyCredits)", category: .credits)
        return true
    }
    
    /// Returns true if user has credits remaining
    func hasCreditsRemaining() -> Bool {
        return dailyCredits > 0
    }
    
    /// Resets credits for testing purposes
    func resetCreditsForTesting() {
        dailyCredits = maxDailyCredits
        UserDefaults.standard.set(dailyCredits, forKey: UserDefaultsKeys.dailyCredits)
        UserDefaults.standard.set(Date(), forKey: creditsResetKey)
        Logger.info("🔄 Credits manually reset to \(maxDailyCredits) for testing", category: .credits)
    }
}

