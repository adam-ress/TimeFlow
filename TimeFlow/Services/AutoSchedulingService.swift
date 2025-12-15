//
//  AutoSchedulingService.swift
//  TimeFlow
//
//  Created during code cleanup
//

import Foundation
import BackgroundTasks

/// Service responsible for auto-scheduling logic and schedule generation checks
@MainActor
class AutoSchedulingService: ObservableObject {
    
    // MARK: - Auto-Scheduling Setup
    
    func setupAutoScheduling(user: User) async {
        // Set default auto-schedule to enabled
        if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSetAutoSchedule) {
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.autoScheduleEnabled)
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasSetAutoSchedule)
        }
        
        // Schedule wake-up generation if auto-scheduling is enabled
        if UserDefaults.standard.bool(forKey: UserDefaultsKeys.autoScheduleEnabled) {
            let wakeTime = user.todaysAwakeHours?.wakeTime ?? user.awakeHours.wakeTime
            BackgroundTaskManager.shared.scheduleWakeUpGeneration(wakeUpTime: wakeTime)
            
            // Cache user data for background generation
            if let userData = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(userData, forKey: UserDefaultsKeys.cachedUserData)
            }
        }
    }
    
    func toggleAutoScheduling(_ enabled: Bool, user: User?) {
        UserDefaults.standard.set(enabled, forKey: UserDefaultsKeys.autoScheduleEnabled)
        
        if enabled {
            // Enable auto-scheduling
            if let user = user {
                let wakeTime = user.todaysAwakeHours?.wakeTime ?? user.awakeHours.wakeTime
                BackgroundTaskManager.shared.scheduleWakeUpGeneration(wakeUpTime: wakeTime)
                
                // Cache user data
                if let userData = try? JSONEncoder().encode(user) {
                    UserDefaults.standard.set(userData, forKey: UserDefaultsKeys.cachedUserData)
                }
            }
        } else {
            // Disable auto-scheduling
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: AppConstants.wakeUpScheduleIdentifier)
        }
    }
    
    func isAutoSchedulingEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: UserDefaultsKeys.autoScheduleEnabled)
    }
    
    // MARK: - Schedule Generation Checks
    
    func checkAndOfferScheduleGeneration(
        user: User,
        scheduleService: ScheduleService
    ) async {
        guard isAutoSchedulingEnabled() else { return }
        
        let wakeTime = user.todaysAwakeHours?.wakeTime ?? user.awakeHours.wakeTime
        
        // Check if we already have a schedule for today
        if !user.currentSchedule.isEmpty {
            Logger.info("✅ Schedule already exists for today", category: .schedule)
            return
        }
        
        // Check if we have a recent background-generated schedule
        if let completedEvents = scheduleService.checkForCompletedSchedule(userSchedule: user.currentSchedule),
           !completedEvents.isEmpty {
            Logger.info("✅ Found background-generated schedule, applying it", category: .schedule)
            return
        }
        
        // Check if it's close to or past wake-up time and we should auto-generate
        if shouldAutoGenerateSchedule(wakeTime: wakeTime) {
            Logger.info("🤖 Auto-generating schedule for today", category: .schedule)
        }
    }
    
    func shouldAutoGenerateSchedule(wakeTime: String) -> Bool {
        guard let wakeUpToday = today(at: wakeTime) else { return false }
        
        let now = Date()
        let timeSinceWakeUp = now.timeIntervalSince(wakeUpToday)
        
        // Auto-generate if:
        // 1. It's within 2 hours after wake-up time, OR
        // 2. It's past 9 AM (fallback for late wake-up times)
        let twoHoursAfterWakeUp = timeSinceWakeUp >= 0 && timeSinceWakeUp <= Double(AppConstants.autoScheduleWindowHours * 60 * 60)
        let past9AM = Calendar.current.component(.hour, from: now) >= AppConstants.autoScheduleFallbackHour
        
        return twoHoursAfterWakeUp || past9AM
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

