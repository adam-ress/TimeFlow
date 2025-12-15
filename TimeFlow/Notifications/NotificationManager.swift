//
//  NotificationManager.swift
//  TimeFlow
//
//  Created by Adam Ress on 7/22/25.
//

import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    // Simple notification types - just two
    enum NotificationType: String, CaseIterable {
        case morningSchedule = "morning_schedule"
        case eveningBedtime = "evening_bedtime"
        
        var displayName: String {
            switch self {
            case .morningSchedule: return "Morning Schedule"
            case .eveningBedtime: return "Evening Reminder"
            }
        }
        
        var description: String {
            switch self {
            case .morningSchedule: return "Get notified when you wake up to plan your day"
            case .eveningBedtime: return "Get reminded to wind down before bedtime"
            }
        }
        
        var icon: String {
            switch self {
            case .morningSchedule: return "sun.max.fill"
            case .eveningBedtime: return "moon.fill"
            }
        }
    }
    
    private init() {
        setupDefaultPreferences()
    }
    
    // MARK: - Permission Management
    
    func requestPermissions() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            Logger.error("❌ Failed to request notification permissions: \(error.localizedDescription)", category: .notifications)
            return false
        }
    }
    
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Preference Management
    
    private func setupDefaultPreferences() {
        let hasSetupDefaults = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSetupNotificationDefaults)
        
        if !hasSetupDefaults {
            // Both notifications enabled by default
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.notificationMorningEnabled)
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.notificationEveningEnabled)
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasSetupNotificationDefaults)
        }
    }
    
    func isMorningNotificationEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: UserDefaultsKeys.notificationMorningEnabled)
    }
    
    func isEveningNotificationEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: UserDefaultsKeys.notificationEveningEnabled)
    }
    
    func setMorningNotificationEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: UserDefaultsKeys.notificationMorningEnabled)
        objectWillChange.send()
    }
    
    func setEveningNotificationEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: UserDefaultsKeys.notificationEveningEnabled)
        objectWillChange.send()
    }
    
    // MARK: - Legacy Support for AccountView
    
    func isEnabled(_ type: NotificationType) -> Bool {
        switch type {
        case .morningSchedule:
            return isMorningNotificationEnabled()
        case .eveningBedtime:
            return isEveningNotificationEnabled()
        }
    }
    
    func setEnabled(_ type: NotificationType, enabled: Bool) {
        switch type {
        case .morningSchedule:
            setMorningNotificationEnabled(enabled)
        case .eveningBedtime:
            setEveningNotificationEnabled(enabled)
        }
    }
    
    // MARK: - Schedule Daily Notifications
    
    func scheduleDailyNotifications(wakeTime: String, sleepTime: String) async {
        // Cancel existing notifications first
        cancelAllNotifications()
        
        // Schedule morning notification
        if isMorningNotificationEnabled() {
            await scheduleMorningNotification(wakeTime: wakeTime)
        }
        
        // Schedule evening notification
        if isEveningNotificationEnabled() {
            await scheduleEveningNotification(sleepTime: sleepTime)
        }
    }
    
    private func scheduleMorningNotification(wakeTime: String) async {
        guard let wakeTimeComponents = parseTimeString(wakeTime) else {
            Logger.error("❌ Invalid wake time format: \(wakeTime)", category: .notifications)
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Good Morning! 🌅"
        content.body = "Ready to plan your day? Let's create your schedule!"
        content.sound = .default
        content.categoryIdentifier = "MORNING_SCHEDULE"
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: wakeTimeComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "morning_schedule",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            Logger.info("✅ Scheduled morning notification for \(wakeTime)", category: .notifications)
        } catch {
            Logger.error("❌ Failed to schedule morning notification: \(error.localizedDescription)", category: .notifications)
        }
    }
    
    private func scheduleEveningNotification(sleepTime: String) async {
        guard let sleepTimeComponents = parseTimeString(sleepTime) else {
            Logger.error("❌ Invalid sleep time format: \(sleepTime)", category: .notifications)
            return
        }
        
        // Calculate 20 minutes before sleep time
        let calendar = Calendar.current
        let sleepHour = sleepTimeComponents.hour ?? 0
        let sleepMinute = sleepTimeComponents.minute ?? 0
        
        var totalMinutes = sleepHour * 60 + sleepMinute - 20
        
        // Handle negative minutes (past midnight)
        if totalMinutes < 0 {
            totalMinutes += 24 * 60 // Add a day's worth of minutes
        }
        
        let reminderHour = totalMinutes / 60
        let reminderMinute = totalMinutes % 60
        
        var reminderComponents = DateComponents()
        reminderComponents.hour = reminderHour
        reminderComponents.minute = reminderMinute
        
        let content = UNMutableNotificationContent()
        content.title = "Wind Down Time 🌙"
        content.body = "Your bedtime is in 20 minutes. Time to start winding down for the night!"
        content.sound = .default
        content.categoryIdentifier = "EVENING_BEDTIME"
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: reminderComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "evening_bedtime",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            let timeString = String(format: "%02d:%02d", reminderHour, reminderMinute)
            Logger.info("✅ Scheduled evening notification for \(timeString)", category: .notifications)
        } catch {
            Logger.error("❌ Failed to schedule evening notification: \(error.localizedDescription)", category: .notifications)
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseTimeString(_ timeString: String) -> DateComponents? {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2,
              components[0] >= 0, components[0] < 24,
              components[1] >= 0, components[1] < 60 else {
            return nil
        }
        
        var dateComponents = DateComponents()
        dateComponents.hour = components[0]
        dateComponents.minute = components[1]
        return dateComponents
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        Logger.info("🧹 Cancelled all notifications", category: .notifications)
    }
    
    func cancelMorningNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning_schedule"])
        Logger.info("🧹 Cancelled morning notification", category: .notifications)
    }
    
    func cancelEveningNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["evening_bedtime"])
        Logger.info("🧹 Cancelled evening notification", category: .notifications)
    }
    
    // MARK: - Debug and Testing Methods
    
    func testMorningNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Good Morning! 🌅"
        content.body = "Ready to plan your day? Let's create your schedule!"
        content.sound = .default
        content.categoryIdentifier = "MORNING_SCHEDULE"
        
        let request = UNNotificationRequest(
            identifier: "test_morning_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            Logger.info("🧪 Test morning notification scheduled for 1 minute from now!", category: .notifications)
        } catch {
            Logger.error("❌ Failed to send test morning notification: \(error.localizedDescription)", category: .notifications)
        }
    }
    
    func testEveningNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Wind Down Time 🌙"
        content.body = "Your bedtime is in 20 minutes. Time to start winding down for the night!"
        content.sound = .default
        content.categoryIdentifier = "EVENING_BEDTIME"
        
        let request = UNNotificationRequest(
            identifier: "test_evening_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            Logger.info("🧪 Test evening notification scheduled for 1 minute from now!", category: .notifications)
        } catch {
            Logger.error("❌ Failed to send test evening notification: \(error.localizedDescription)", category: .notifications)
        }
    }
    
    func checkPendingNotifications() async {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        
        var message = "📋 Pending Notifications (\(requests.count)):\n"
        for request in requests {
            let triggerInfo: String
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                let hour = trigger.dateComponents.hour ?? 0
                let minute = trigger.dateComponents.minute ?? 0
                triggerInfo = String(format: "daily at %02d:%02d", hour, minute)
            } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                let fireDate = Date().addingTimeInterval(trigger.timeInterval)
                triggerInfo = "fires at \(fireDate.formatted(date: .abbreviated, time: .shortened))"
            } else {
                triggerInfo = "immediate"
            }
            
            message += "  • \(request.identifier): \(request.content.title) - \(triggerInfo)\n"
        }
        
        if requests.isEmpty {
            message += "  No pending notifications"
        }
        
        Logger.debug(message, category: .notifications)
    }
    
    func checkDeliveredNotifications() async {
        let center = UNUserNotificationCenter.current()
        let notifications = await center.deliveredNotifications()
        
        var message = "📬 Delivered Notifications (\(notifications.count)):\n"
        for notification in notifications {
            let deliveredAt = notification.date.formatted(date: .abbreviated, time: .shortened)
            message += "  • \(notification.request.identifier): \(notification.request.content.title) - delivered at \(deliveredAt)\n"
        }
        
        if notifications.isEmpty {
            message += "  No delivered notifications"
        }
        
        Logger.debug(message, category: .notifications)
    }
    
    func checkNotificationSettings() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        var message = """
        🔔 Notification Settings:
          • Authorization: \(settings.authorizationStatus.description)
          • Alert Setting: \(settings.alertSetting.description)
          • Badge Setting: \(settings.badgeSetting.description)
          • Sound Setting: \(settings.soundSetting.description)
        """
        
        if settings.authorizationStatus == .denied {
            message += "\n  ⚠️ Notifications are DISABLED in system settings!"
        } else if settings.authorizationStatus == .authorized {
            message += "\n  ✅ Notifications are properly authorized"
        }
        
        Logger.debug(message, category: .notifications)
    }
}

// MARK: - Notification Categories Setup
extension NotificationManager {
    func setupNotificationCategories() {
        let morningActions = [
            UNNotificationAction(
                identifier: "OPEN_APP",
                title: "Open TimeFlow",
                options: [.foreground]
            )
        ]
        
        let eveningActions = [
            UNNotificationAction(
                identifier: "SNOOZE_10",
                title: "Remind in 10 min",
                options: []
            )
        ]
        
        let categories = [
            UNNotificationCategory(
                identifier: "MORNING_SCHEDULE",
                actions: morningActions,
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: "EVENING_BEDTIME",
                actions: eveningActions,
                intentIdentifiers: [],
                options: []
            )
        ]
        
        UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
    }
}

// MARK: - Extensions for better debugging
extension UNAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }
}

extension UNNotificationSetting {
    var description: String {
        switch self {
        case .notSupported: return "Not Supported"
        case .disabled: return "Disabled"
        case .enabled: return "Enabled"
        @unknown default: return "Unknown"
        }
    }
}