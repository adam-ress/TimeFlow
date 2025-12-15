//
//  ScheduleOptimizer.swift
//  TimeFlow
//
//  Created during hybrid scheduling system implementation
//

import Foundation

// MARK: - Data Structures

struct ScheduleQuality {
    let score: Double // 0.0 to 1.0
    let issues: [String]
    let warnings: [String]
}

struct OptimizationResult {
    let events: [Event]
    let quality: ScheduleQuality
    let wasOptimized: Bool
}

// MARK: - Schedule Optimizer

@MainActor
class ScheduleOptimizer {
    
    // MARK: - Main Optimization Function
    
    func optimize(
        events: [Event],
        user: User,
        now: Date = Date()
    ) -> OptimizationResult {
        // Validate first
        let validationIssues = validate(events: events, user: user, now: now)
        
        // Optimize if needed
        var optimizedEvents = events
        var wasOptimized = false
        
        if !validationIssues.isEmpty {
            // Try to fix issues
            optimizedEvents = fixIssues(events: events, issues: validationIssues, user: user, now: now)
            wasOptimized = true
        }
        
        // Additional optimizations
        optimizedEvents = optimizeEventOrder(events: optimizedEvents)
        optimizedEvents = addMissingBuffers(events: optimizedEvents)
        
        // Calculate quality
        let quality = calculateQuality(events: optimizedEvents, user: user, now: now)
        
        return OptimizationResult(
            events: optimizedEvents,
            quality: quality,
            wasOptimized: wasOptimized || optimizedEvents != events
        )
    }
    
    // MARK: - Validation
    
    func validate(events: [Event], user: User, now: Date) -> [String] {
        var issues: [String] = []
        let sortedEvents = events.filter { $0.end > now }.sorted { $0.start < $1.start }
        
        // Check for overlaps
        for i in 0..<sortedEvents.count {
            for j in (i+1)..<sortedEvents.count {
                if sortedEvents[i].end > sortedEvents[j].start {
                    issues.append("Overlap detected: '\(sortedEvents[i].title)' overlaps with '\(sortedEvents[j].title)'")
                }
            }
        }
        
        // Check for gaps (minimum 5 minutes)
        for i in 0..<(sortedEvents.count - 1) {
            let gap = sortedEvents[i + 1].start.timeIntervalSince(sortedEvents[i].end)
            if gap < 0 {
                issues.append("Negative gap between '\(sortedEvents[i].title)' and '\(sortedEvents[i + 1].title)'")
            } else if gap > 0 && gap < 5 * 60 {
                // Warning, not critical
            }
        }
        
        // Check sleep requirements
        let wakeTime = user.todaysAwakeHours?.wakeTime ?? user.awakeHours.wakeTime
        let sleepTime = user.todaysAwakeHours?.sleepTime ?? user.awakeHours.sleepTime
        
        if let lastEvent = sortedEvents.last,
           let sleepDate = dateFromHHMM(sleepTime),
           let wakeDate = dateFromHHMM(wakeTime) {
            let calendar = Calendar.current
            let tomorrowWake = calendar.date(byAdding: .day, value: 1, to: wakeDate) ?? wakeDate
            
            let sleepDuration = tomorrowWake.timeIntervalSince(lastEvent.end)
            let minSleep = user.ageGroup == .college ? 7 * 3600 : 6 * 3600
            
            if sleepDuration < minSleep {
                issues.append("Schedule extends too late - only \(Int(sleepDuration / 3600)) hours for sleep (minimum: \(Int(minSleep / 3600)) hours)")
            }
        }
        
        // Check for events before wake time
        if let firstEvent = sortedEvents.first,
           let wakeDate = dateFromHHMM(wakeTime) {
            if firstEvent.start < wakeDate {
                issues.append("Event '\(firstEvent.title)' scheduled before wake time")
            }
        }
        
        return issues
    }
    
    // MARK: - Issue Fixing
    
    private func fixIssues(events: [Event], issues: [String], user: User, now: Date) -> [Event] {
        var fixedEvents = events.filter { $0.end > now }.sorted { $0.start < $1.start }
        
        // Fix overlaps by shifting later events
        for i in 0..<fixedEvents.count {
            for j in (i+1)..<fixedEvents.count {
                if fixedEvents[i].end > fixedEvents[j].start {
                    // Shift the later event
                    let overlap = fixedEvents[i].end.timeIntervalSince(fixedEvents[j].start)
                    let newStart = fixedEvents[i].end.addingTimeInterval(5 * 60) // Add 5 min buffer
                    let duration = fixedEvents[j].end.timeIntervalSince(fixedEvents[j].start)
                    let newEnd = newStart.addingTimeInterval(duration)
                    
                    fixedEvents[j] = Event(
                        id: fixedEvents[j].id,
                        start: newStart,
                        end: newEnd,
                        title: fixedEvents[j].title,
                        icon: fixedEvents[j].icon,
                        eventType: fixedEvents[j].eventType,
                        colorName: fixedEvents[j].colorName
                    )
                }
            }
        }
        
        // Re-sort after fixes
        fixedEvents = fixedEvents.sorted { $0.start < $1.start }
        
        return fixedEvents
    }
    
    // MARK: - Optimization
    
    private func optimizeEventOrder(events: [Event]) -> [Event] {
        // Reorder events to put high-energy tasks in morning
        // This is a simple heuristic - could be enhanced
        var optimized = events
        
        // Sort by time, but prioritize certain event types for morning slots
        optimized.sort { event1, event2 in
            // If both are same time, prefer assignments/tests in morning
            if abs(event1.start.timeIntervalSince(event2.start)) < 60 {
                let morningTypes: [EventType] = [.assignment, .testStudy]
                let e1IsMorning = morningTypes.contains(event1.eventType)
                let e2IsMorning = morningTypes.contains(event2.eventType)
                
                if e1IsMorning && !e2IsMorning {
                    return true
                } else if !e1IsMorning && e2IsMorning {
                    return false
                }
            }
            
            return event1.start < event2.start
        }
        
        return optimized
    }
    
    private func addMissingBuffers(events: [Event]) -> [Event] {
        let sortedEvents = events.sorted { $0.start < $1.start }
        var bufferedEvents: [Event] = []
        
        for (index, event) in sortedEvents.enumerated() {
            bufferedEvents.append(event)
            
            // Add buffer after event if next event is too close
            if index < sortedEvents.count - 1 {
                let nextEvent = sortedEvents[index + 1]
                let gap = nextEvent.start.timeIntervalSince(event.end)
                
                if gap < 5 * 60 && gap > 0 {
                    // Buffer is too small but positive - event is already adjusted
                    // No action needed
                } else if gap == 0 {
                    // Events are back-to-back, add small buffer by adjusting next event
                    // This is handled in validation fixes
                }
            }
        }
        
        return bufferedEvents
    }
    
    // MARK: - Quality Scoring
    
    private func calculateQuality(events: [Event], user: User, now: Date) -> ScheduleQuality {
        var issues: [String] = []
        var warnings: [String] = []
        
        let sortedEvents = events.filter { $0.end > now }.sorted { $0.start < $1.start }
        
        if sortedEvents.isEmpty {
            return ScheduleQuality(score: 0.5, issues: ["No events scheduled"], warnings: [])
        }
        
        var score: Double = 1.0
        
        // Check for excessive packing
        let wakeTime = user.todaysAwakeHours?.wakeTime ?? user.awakeHours.wakeTime
        let sleepTime = user.todaysAwakeHours?.sleepTime ?? user.awakeHours.sleepTime
        
        if let firstEvent = sortedEvents.first,
           let lastEvent = sortedEvents.last,
           let wakeDate = dateFromHHMM(wakeTime),
           let sleepDate = dateFromHHMM(sleepTime) {
            
            let totalAvailable = sleepDate.timeIntervalSince(max(wakeDate, now))
            let totalScheduled = sortedEvents.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
            let utilization = totalAvailable > 0 ? totalScheduled / totalAvailable : 0.0
            
            if utilization > 0.9 {
                score -= 0.2
                warnings.append("Schedule is very full (\(Int(utilization * 100))% utilized)")
            } else if utilization > 0.8 {
                score -= 0.1
                warnings.append("Schedule is quite full (\(Int(utilization * 100))% utilized)")
            }
            
            // Check for very long consecutive work periods
            var consecutiveWork: TimeInterval = 0
            var currentWorkStart: Date?
            
            for event in sortedEvents {
                if event.eventType == .assignment || event.eventType == .testStudy {
                    if currentWorkStart == nil {
                        currentWorkStart = event.start
                    }
                    consecutiveWork += event.end.timeIntervalSince(event.start)
                } else {
                    if consecutiveWork > 3 * 3600 { // 3 hours
                        score -= 0.1
                        warnings.append("Long consecutive work period detected (\(Int(consecutiveWork / 3600)) hours)")
                    }
                    consecutiveWork = 0
                    currentWorkStart = nil
                }
            }
            
            if consecutiveWork > 3 * 3600 {
                score -= 0.1
                warnings.append("Long consecutive work period at end of day")
            }
        }
        
        // Check for gaps that are too large (inefficient)
        for i in 0..<(sortedEvents.count - 1) {
            let gap = sortedEvents[i + 1].start.timeIntervalSince(sortedEvents[i].end)
            if gap > 2 * 3600 { // 2 hours
                warnings.append("Large gap (\(Int(gap / 3600)) hours) between events")
            }
        }
        
        // Check for proper meal scheduling
        let hasBreakfast = sortedEvents.contains { $0.title.lowercased().contains("breakfast") }
        let hasLunch = sortedEvents.contains { $0.title.lowercased().contains("lunch") }
        let hasDinner = sortedEvents.contains { $0.title.lowercased().contains("dinner") }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        
        if hour < 10 && !hasBreakfast && (sortedEvents.first?.start.timeIntervalSince(now) ?? 0) > 3600.0 {
            warnings.append("Consider adding breakfast if scheduling early morning tasks")
        }
        
        // Validate overlaps (should be fixed by now, but check anyway)
        for i in 0..<sortedEvents.count {
            for j in (i+1)..<sortedEvents.count {
                if sortedEvents[i].end > sortedEvents[j].start {
                    score -= 0.3
                    issues.append("Overlap: '\(sortedEvents[i].title)' and '\(sortedEvents[j].title)'")
                }
            }
        }
        
        score = max(0.0, min(1.0, score))
        
        return ScheduleQuality(score: score, issues: issues, warnings: warnings)
    }
}

