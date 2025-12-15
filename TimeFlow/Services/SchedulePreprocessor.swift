//
//  SchedulePreprocessor.swift
//  TimeFlow
//
//  Created during hybrid scheduling system implementation
//

import Foundation

// MARK: - Data Structures

struct TimeSlot {
    let start: Date
    let end: Date
    let duration: TimeInterval
    let qualityScore: Double // 0.0 to 1.0 based on time of day, size, etc.
    let dayOffset: Int // 0 = today, 1 = tomorrow, etc.
}

struct TaskChunk {
    let assignmentId: UUID
    let title: String
    let durationMinutes: Int
    let priority: Double // 0.0 to 1.0
    let suggestedDay: Int? // 0 = today, 1 = tomorrow, nil = flexible
    let canDefer: Bool
}

struct PreprocessingResult {
    let availableTimeSlots: [TimeSlot]
    let taskBreakdowns: [TaskChunk]
    let priorityScores: [UUID: Double]
    let workloadRecommendations: String
}

// MARK: - Schedule Preprocessor

@MainActor
class SchedulePreprocessor {
    
    // MARK: - Main Preprocessing Function
    
    func preprocess(
        user: User,
        now: Date = Date()
    ) -> PreprocessingResult {
        let calendar = Calendar.current
        
        // Get fixed events for today and next 2 days
        let fixedEventsToday = getFixedEvents(for: user, dayOffset: 0, now: now)
        let fixedEventsTomorrow = getFixedEvents(for: user, dayOffset: 1, now: now)
        let fixedEventsDayAfter = getFixedEvents(for: user, dayOffset: 2, now: now)
        
        // Find available time slots
        let wakeTime = user.todaysAwakeHours?.wakeTime ?? user.awakeHours.wakeTime
        let sleepTime = user.todaysAwakeHours?.sleepTime ?? user.awakeHours.sleepTime
        
        let slotsToday = findAvailableTimeSlots(
            fixedEvents: fixedEventsToday,
            wakeTime: wakeTime,
            sleepTime: sleepTime,
            now: now,
            dayOffset: 0
        )
        
        let slotsTomorrow = findAvailableTimeSlots(
            fixedEvents: fixedEventsTomorrow,
            wakeTime: wakeTime,
            sleepTime: sleepTime,
            now: now,
            dayOffset: 1
        )
        
        let slotsDayAfter = findAvailableTimeSlots(
            fixedEvents: fixedEventsDayAfter,
            wakeTime: wakeTime,
            sleepTime: sleepTime,
            now: now,
            dayOffset: 2
        )
        
        let allSlots = slotsToday + slotsTomorrow + slotsDayAfter
        
        // Analyze tasks and suggest breakdowns
        let taskBreakdowns = analyzeTasks(user: user, now: now)
        
        // Calculate priority scores
        let priorityScores = calculatePriorityScores(user: user, now: now)
        
        // Generate workload recommendations
        let workloadRecommendations = generateWorkloadRecommendations(
            slotsToday: slotsToday,
            slotsTomorrow: slotsTomorrow,
            slotsDayAfter: slotsDayAfter,
            taskBreakdowns: taskBreakdowns
        )
        
        return PreprocessingResult(
            availableTimeSlots: allSlots,
            taskBreakdowns: taskBreakdowns,
            priorityScores: priorityScores,
            workloadRecommendations: workloadRecommendations
        )
    }
    
    // MARK: - Time Slot Discovery
    
    private func findAvailableTimeSlots(
        fixedEvents: [Event],
        wakeTime: String,
        sleepTime: String,
        now: Date,
        dayOffset: Int
    ) -> [TimeSlot] {
        guard let wakeDate = dateForDay(wakeTime, dayOffset: dayOffset, now: now),
              let sleepDate = dateForDay(sleepTime, dayOffset: dayOffset, now: now) else {
            return []
        }
        
        let calendar = Calendar.current
        let dayStart = max(wakeDate, dayOffset == 0 ? now : wakeDate)
        let dayEnd = sleepDate
        
        // Merge overlapping fixed events
        let mergedEvents = mergeOverlappingEvents(fixedEvents.sorted { $0.start < $1.start })
        
        // Find gaps between events
        var slots: [TimeSlot] = []
        var currentTime = dayStart
        
        for event in mergedEvents {
            // If there's a gap before this event
            if currentTime < event.start {
                let gapDuration = event.start.timeIntervalSince(currentTime)
                // Only include gaps >= 15 minutes
                if gapDuration >= 15 * 60 {
                    let quality = calculateSlotQuality(start: currentTime, end: event.start, dayOffset: dayOffset)
                    slots.append(TimeSlot(
                        start: currentTime,
                        end: event.start,
                        duration: gapDuration,
                        qualityScore: quality,
                        dayOffset: dayOffset
                    ))
                }
            }
            currentTime = max(currentTime, event.end)
        }
        
        // Check gap after last event until sleep time
        if currentTime < dayEnd {
            let gapDuration = dayEnd.timeIntervalSince(currentTime)
            if gapDuration >= 15 * 60 {
                let quality = calculateSlotQuality(start: currentTime, end: dayEnd, dayOffset: dayOffset)
                slots.append(TimeSlot(
                    start: currentTime,
                    end: dayEnd,
                    duration: gapDuration,
                    qualityScore: quality,
                    dayOffset: dayOffset
                ))
            }
        }
        
        return slots.sorted { $0.qualityScore > $1.qualityScore }
    }
    
    private func calculateSlotQuality(start: Date, end: Date, dayOffset: Int) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: start)
        let duration = end.timeIntervalSince(start)
        
        var score: Double = 0.5 // Base score
        
        // Time of day preference (morning and early afternoon are better)
        if hour >= 6 && hour < 10 {
            score += 0.3 // Morning boost
        } else if hour >= 10 && hour < 14 {
            score += 0.2 // Early afternoon
        } else if hour >= 14 && hour < 18 {
            score += 0.1 // Late afternoon
        } else if hour >= 18 && hour < 22 {
            score += 0.0 // Evening (neutral)
        } else {
            score -= 0.2 // Late night penalty
        }
        
        // Duration preference (60-120 minutes is optimal)
        if duration >= 60 * 60 && duration <= 120 * 60 {
            score += 0.2
        } else if duration >= 30 * 60 && duration < 60 * 60 {
            score += 0.1
        } else if duration >= 120 * 60 && duration <= 180 * 60 {
            score += 0.05
        } else if duration < 30 * 60 {
            score -= 0.1 // Too short
        } else {
            score -= 0.05 // Very long
        }
        
        // Penalty for future days (prefer today)
        if dayOffset > 0 {
            score -= Double(dayOffset) * 0.1
        }
        
        return min(1.0, max(0.0, score))
    }
    
    // MARK: - Task Analysis & Breakdown
    
    private func analyzeTasks(user: User, now: Date) -> [TaskChunk] {
        var chunks: [TaskChunk] = []
        let calendar = Calendar.current
        
        // Analyze assignments
        for assignment in user.assignments.filter({ !$0.completed }) {
            let daysUntilDue = calendar.dateComponents([.day], from: now, to: assignment.dueDate).day ?? 0
            let totalMinutes = assignment.estimatedMinutesLeftToComplete
            
            // Calculate priority
            let priority: Double
            if daysUntilDue <= 0 {
                priority = 1.0 // Overdue
            } else if daysUntilDue == 1 {
                priority = 0.9 // Due tomorrow
            } else if daysUntilDue <= 3 {
                priority = 0.7 // Due soon
            } else if daysUntilDue <= 7 {
                priority = 0.5 // Due this week
            } else {
                priority = 0.3 // Not urgent
            }
            
            // Suggest breakdown for large tasks
            if totalMinutes > 120 {
                // Break into 60-90 minute chunks
                let chunkSize = min(90, max(60, totalMinutes / 2))
                let numChunks = Int(ceil(Double(totalMinutes) / Double(chunkSize)))
                
                for i in 0..<numChunks {
                    let chunkMinutes = i == numChunks - 1 ? totalMinutes - (chunkSize * i) : chunkSize
                    let canDefer = daysUntilDue > 1 && i > 0 // Can defer non-first chunks if not urgent
                    let suggestedDay: Int? = daysUntilDue <= 1 ? 0 : (i == 0 ? 0 : nil) // First chunk today if urgent
                    
                    chunks.append(TaskChunk(
                        assignmentId: assignment.id,
                        title: "\(assignment.assignmentTitle) - Part \(i + 1)",
                        durationMinutes: chunkMinutes,
                        priority: priority * (i == 0 ? 1.0 : 0.8), // First chunk has higher priority
                        suggestedDay: suggestedDay,
                        canDefer: canDefer
                    ))
                }
            } else {
                // Small task, no breakdown needed
                let canDefer = daysUntilDue > 1
                let suggestedDay: Int? = daysUntilDue <= 1 ? 0 : nil
                
                chunks.append(TaskChunk(
                    assignmentId: assignment.id,
                    title: assignment.assignmentTitle,
                    durationMinutes: totalMinutes,
                    priority: priority,
                    suggestedDay: suggestedDay,
                    canDefer: canDefer
                ))
            }
        }
        
        // Analyze tests
        for test in user.tests.filter({ !$0.prepared }) {
            let daysUntilTest = calendar.dateComponents([.day], from: now, to: test.date).day ?? 0
            let totalMinutes = test.studyMinutesLeft
            
            let priority: Double
            if daysUntilTest <= 1 {
                priority = 0.95 // Test tomorrow or today
            } else if daysUntilTest <= 3 {
                priority = 0.8 // Test soon
            } else if daysUntilTest <= 7 {
                priority = 0.6 // Test this week
            } else {
                priority = 0.4 // Test later
            }
            
            // Break test study into chunks
            if totalMinutes > 90 {
                let chunkSize = 60
                let numChunks = Int(ceil(Double(totalMinutes) / Double(chunkSize)))
                
                for i in 0..<numChunks {
                    let chunkMinutes = i == numChunks - 1 ? totalMinutes - (chunkSize * i) : chunkSize
                    let canDefer = daysUntilTest > 2 && i > 0
                    let suggestedDay: Int? = daysUntilTest <= 2 ? 0 : (i == 0 ? 0 : nil)
                    
                    chunks.append(TaskChunk(
                        assignmentId: test.id, // Reusing assignmentId field for test ID
                        title: "Study for \(test.testTitle) - Session \(i + 1)",
                        durationMinutes: chunkMinutes,
                        priority: priority * (i == 0 ? 1.0 : 0.8),
                        suggestedDay: suggestedDay,
                        canDefer: canDefer
                    ))
                }
            } else {
                let canDefer = daysUntilTest > 2
                let suggestedDay: Int? = daysUntilTest <= 2 ? 0 : nil
                
                chunks.append(TaskChunk(
                    assignmentId: test.id,
                    title: "Study for \(test.testTitle)",
                    durationMinutes: totalMinutes,
                    priority: priority,
                    suggestedDay: suggestedDay,
                    canDefer: canDefer
                ))
            }
        }
        
        return chunks.sorted { $0.priority > $1.priority }
    }
    
    // MARK: - Priority Calculation
    
    private func calculatePriorityScores(user: User, now: Date) -> [UUID: Double] {
        var scores: [UUID: Double] = [:]
        let calendar = Calendar.current
        
        // Assignment priorities
        for assignment in user.assignments.filter({ !$0.completed }) {
            let daysUntilDue = calendar.dateComponents([.day], from: now, to: assignment.dueDate).day ?? 0
            if daysUntilDue <= 0 {
                scores[assignment.id] = 1.0
            } else if daysUntilDue == 1 {
                scores[assignment.id] = 0.9
            } else if daysUntilDue <= 3 {
                scores[assignment.id] = 0.7
            } else if daysUntilDue <= 7 {
                scores[assignment.id] = 0.5
            } else {
                scores[assignment.id] = 0.3
            }
        }
        
        // Test priorities
        for test in user.tests.filter({ !$0.prepared }) {
            let daysUntilTest = calendar.dateComponents([.day], from: now, to: test.date).day ?? 0
            if daysUntilTest <= 1 {
                scores[test.id] = 0.95
            } else if daysUntilTest <= 3 {
                scores[test.id] = 0.8
            } else if daysUntilTest <= 7 {
                scores[test.id] = 0.6
            } else {
                scores[test.id] = 0.4
            }
        }
        
        return scores
    }
    
    // MARK: - Workload Recommendations
    
    private func generateWorkloadRecommendations(
        slotsToday: [TimeSlot],
        slotsTomorrow: [TimeSlot],
        slotsDayAfter: [TimeSlot],
        taskBreakdowns: [TaskChunk]
    ) -> String {
        let todayAvailable = slotsToday.reduce(0) { $0 + $1.duration }
        let tomorrowAvailable = slotsTomorrow.reduce(0) { $0 + $1.duration }
        let dayAfterAvailable = slotsDayAfter.reduce(0) { $0 + $1.duration }
        
        let todayTaskMinutes = taskBreakdowns.filter { $0.suggestedDay == 0 || $0.suggestedDay == nil }
            .reduce(0) { $0 + $1.durationMinutes } * 60
        
        let tomorrowTaskMinutes = taskBreakdowns.filter { $0.suggestedDay == 1 }
            .reduce(0) { $0 + $1.durationMinutes } * 60
        
        let todayUtilization = todayAvailable > 0 ? todayTaskMinutes / todayAvailable : 0.0
        let tomorrowUtilization = tomorrowAvailable > 0 ? tomorrowTaskMinutes / tomorrowAvailable : 0.0
        
        var recommendations: [String] = []
        
        // Check for imbalance
        if todayUtilization > 0.8 && tomorrowUtilization < 0.4 && tomorrowAvailable > 0 {
            recommendations.append("⚠️ Today is overpacked (\(Int(todayUtilization * 100))% utilized) while tomorrow is light (\(Int(tomorrowUtilization * 100))% utilized). Consider deferring some non-urgent tasks to tomorrow.")
        } else if todayUtilization > 0.9 {
            recommendations.append("⚠️ Today is very full (\(Int(todayUtilization * 100))% utilized). Only schedule critical tasks today.")
        } else if todayUtilization < 0.3 && tomorrowUtilization > 0.6 {
            recommendations.append("ℹ️ Tomorrow is busier than today. You can schedule more tasks today if needed.")
        }
        
        // Provide specific guidance
        if tomorrowAvailable > todayAvailable * 1.5 && tomorrowUtilization < 0.5 {
            recommendations.append("💡 Tomorrow has significantly more free time. Consider deferring flexible tasks (especially those marked as deferrable) to balance the workload.")
        }
        
        if recommendations.isEmpty {
            recommendations.append("✅ Workload is well-balanced across days.")
        }
        
        return recommendations.joined(separator: "\n")
    }
    
    // MARK: - Helper Functions
    
    private func getFixedEvents(for user: User, dayOffset: Int, now: Date) -> [Event] {
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
        let weekdayIdx = calendar.component(.weekday, from: targetDate)
        let weekday = Weekday.allCases[(weekdayIdx + 5) % 7]
        var events: [Event] = []
        
        // School hours (for students)
        if user.ageGroup == .highSchool || user.ageGroup == .middleSchool {
            if weekday != .saturday && weekday != .sunday {
                if let start = dateForDay(user.schoolHours.startTime, dayOffset: dayOffset, now: now),
                   let end = dateForDay(user.schoolHours.endTime, dayOffset: dayOffset, now: now) {
                    events.append(Event(
                        start: start,
                        end: end,
                        title: "School",
                        eventType: .school
                    ))
                }
            }
        }
        
        // College courses
        for course in user.collegeCourses where course.day == weekday {
            if let start = dateForDay(course.startTime, dayOffset: dayOffset, now: now),
               let end = dateForDay(course.endTime, dayOffset: dayOffset, now: now) {
                events.append(Event(
                    id: course.id,
                    start: start,
                    end: end,
                    title: course.name,
                    eventType: .collegeClass,
                    colorName: course.colorName
                ))
            }
        }
        
        // Work hours (for professionals)
        if let workHours = user.workHours.first(where: { $0.day == weekday && $0.enabled }) {
            if let start = dateForDay(workHours.startTime, dayOffset: dayOffset, now: now),
               let end = dateForDay(workHours.endTime, dayOffset: dayOffset, now: now) {
                events.append(Event(
                    id: workHours.id,
                    start: start,
                    end: end,
                    title: "Work",
                    eventType: .work
                ))
            }
        }
        
        // Recurring commitments
        for commitment in user.recurringCommitments {
            let isToday: Bool
            switch commitment.cadence {
            case .daily:
                isToday = true
            case .weekdays:
                isToday = weekday != .saturday && weekday != .sunday
            case .custom:
                isToday = commitment.customDays.contains(weekday)
            }
            
            if isToday {
                if let start = dateForDay(commitment.startTime, dayOffset: dayOffset, now: now),
                   let end = dateForDay(commitment.endTime, dayOffset: dayOffset, now: now) {
                    events.append(Event(
                        id: commitment.id,
                        start: start,
                        end: end,
                        title: commitment.title,
                        icon: commitment.icon,
                        eventType: .recurringCommitment,
                        colorName: commitment.colorName
                    ))
                }
            }
        }
        
        return events.sorted { $0.start < $1.start }
    }
    
    private func mergeOverlappingEvents(_ events: [Event]) -> [Event] {
        guard !events.isEmpty else { return [] }
        var merged: [Event] = []
        
        for event in events {
            if let last = merged.last, event.start <= last.end {
                // Merge with last event
                merged[merged.count - 1] = Event(
                    id: last.id,
                    start: last.start,
                    end: max(last.end, event.end),
                    title: last.title,
                    icon: last.icon,
                    eventType: last.eventType,
                    colorName: last.colorName
                )
            } else {
                merged.append(event)
            }
        }
        
        return merged
    }
    
    private func dateForDay(_ hhmm: String, dayOffset: Int, now: Date) -> Date? {
        guard let baseDate = dateFromHHMM(hhmm) else { return nil }
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: dayOffset, to: baseDate)
    }
}

