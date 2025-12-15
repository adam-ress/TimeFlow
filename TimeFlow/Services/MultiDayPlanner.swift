//
//  MultiDayPlanner.swift
//  TimeFlow
//
//  Created during hybrid scheduling system implementation
//

import Foundation

// MARK: - Data Structures

struct DayWorkload {
    let dayOffset: Int // 0 = today, 1 = tomorrow, etc.
    let availableMinutes: Int
    let scheduledMinutes: Int
    let fixedCommitmentsMinutes: Int
    let utilizationRate: Double // 0.0 to 1.0
    let isWeekend: Bool
}

struct WorkloadBalance {
    let today: DayWorkload
    let tomorrow: DayWorkload
    let dayAfter: DayWorkload
    let recommendation: String
    let tasksToDefer: [UUID]
    let imbalanceSeverity: Double // 0.0 to 1.0
}

// MARK: - Multi-Day Planner

@MainActor
class MultiDayPlanner {
    
    // MARK: - Main Analysis Function
    
    func analyzeWorkload(
        user: User,
        todaySlots: [TimeSlot],
        tomorrowSlots: [TimeSlot],
        dayAfterSlots: [TimeSlot],
        taskBreakdowns: [TaskChunk],
        now: Date = Date()
    ) -> WorkloadBalance {
        let calendar = Calendar.current
        
        // Calculate today's workload
        let today = calculateDayWorkload(
            dayOffset: 0,
            slots: todaySlots,
            taskBreakdowns: taskBreakdowns,
            user: user,
            now: now
        )
        
        // Calculate tomorrow's workload
        let tomorrow = calculateDayWorkload(
            dayOffset: 1,
            slots: tomorrowSlots,
            taskBreakdowns: taskBreakdowns,
            user: user,
            now: now
        )
        
        // Calculate day after's workload
        let dayAfter = calculateDayWorkload(
            dayOffset: 2,
            slots: dayAfterSlots,
            taskBreakdowns: taskBreakdowns,
            user: user,
            now: now
        )
        
        // Generate recommendations
        let (recommendation, tasksToDefer, imbalanceSeverity) = generateRecommendations(
            today: today,
            tomorrow: tomorrow,
            dayAfter: dayAfter,
            taskBreakdowns: taskBreakdowns
        )
        
        return WorkloadBalance(
            today: today,
            tomorrow: tomorrow,
            dayAfter: dayAfter,
            recommendation: recommendation,
            tasksToDefer: tasksToDefer,
            imbalanceSeverity: imbalanceSeverity
        )
    }
    
    // MARK: - Day Workload Calculation
    
    private func calculateDayWorkload(
        dayOffset: Int,
        slots: [TimeSlot],
        taskBreakdowns: [TaskChunk],
        user: User,
        now: Date
    ) -> DayWorkload {
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
        let weekdayIdx = calendar.component(.weekday, from: targetDate)
        let weekday = Weekday.allCases[(weekdayIdx + 5) % 7]
        let isWeekend = weekday == .saturday || weekday == .sunday
        
        // Calculate available time from slots
        let availableMinutes = Int(slots.reduce(0) { $0 + $1.duration } / 60)
        
        // Calculate fixed commitments
        let fixedCommitments = getFixedCommitmentsForDay(user: user, weekday: weekday, dayOffset: dayOffset, now: now)
        let fixedCommitmentsMinutes = fixedCommitments.reduce(0) { total, event in
            total + Int(event.end.timeIntervalSince(event.start) / 60)
        }
        
        // Calculate scheduled tasks (tasks suggested for this day)
        let scheduledTasks = taskBreakdowns.filter { chunk in
            if let suggestedDay = chunk.suggestedDay {
                return suggestedDay == dayOffset
            }
            // If no suggested day and it's today, assume it's for today
            return dayOffset == 0
        }
        let scheduledMinutes = scheduledTasks.reduce(0) { $0 + $1.durationMinutes }
        
        // Calculate utilization (scheduled + fixed) / available
        let totalUsed = scheduledMinutes + fixedCommitmentsMinutes
        let totalAvailable = availableMinutes + fixedCommitmentsMinutes
        let utilizationRate = totalAvailable > 0 ? Double(totalUsed) / Double(totalAvailable) : 0.0
        
        return DayWorkload(
            dayOffset: dayOffset,
            availableMinutes: availableMinutes,
            scheduledMinutes: scheduledMinutes,
            fixedCommitmentsMinutes: fixedCommitmentsMinutes,
            utilizationRate: utilizationRate,
            isWeekend: isWeekend
        )
    }
    
    // MARK: - Recommendations
    
    private func generateRecommendations(
        today: DayWorkload,
        tomorrow: DayWorkload,
        dayAfter: DayWorkload,
        taskBreakdowns: [TaskChunk]
    ) -> (recommendation: String, tasksToDefer: [UUID], imbalanceSeverity: Double) {
        var recommendations: [String] = []
        var tasksToDefer: [UUID] = []
        var imbalanceSeverity: Double = 0.0
        
        // Calculate imbalance
        let todayUtil = today.utilizationRate
        let tomorrowUtil = tomorrow.utilizationRate
        let dayAfterUtil = dayAfter.utilizationRate
        
        // Check if today is overpacked
        if todayUtil > 0.85 && tomorrowUtil < 0.6 {
            let imbalance = todayUtil - tomorrowUtil
            imbalanceSeverity = min(1.0, imbalance)
            
            if imbalance > 0.3 {
                recommendations.append("⚠️ CRITICAL: Today is \(Int(todayUtil * 100))% full while tomorrow is only \(Int(tomorrowUtil * 100))% full. Strongly recommend deferring non-urgent tasks.")
                
                // Find deferrable tasks
                let deferrable = taskBreakdowns.filter { chunk in
                    chunk.canDefer && chunk.priority < 0.7 && (chunk.suggestedDay == 0 || chunk.suggestedDay == nil)
                }
                tasksToDefer = Array(deferrable.prefix(3).map { $0.assignmentId })
            } else if imbalance > 0.2 {
                recommendations.append("⚠️ Today is \(Int(todayUtil * 100))% full while tomorrow is \(Int(tomorrowUtil * 100))% full. Consider deferring some flexible tasks.")
                
                let deferrable = taskBreakdowns.filter { chunk in
                    chunk.canDefer && chunk.priority < 0.6 && (chunk.suggestedDay == 0 || chunk.suggestedDay == nil)
                }
                tasksToDefer = Array(deferrable.prefix(2).map { $0.assignmentId })
            }
        }
        
        // Check if tomorrow is much busier
        if tomorrowUtil > todayUtil + 0.2 && todayUtil < 0.7 {
            recommendations.append("ℹ️ Tomorrow is busier than today. You have room to schedule more tasks today if needed.")
        }
        
        // Check for weekend considerations
        if tomorrow.isWeekend && todayUtil > 0.7 {
            recommendations.append("💡 Tomorrow is a weekend. Consider deferring non-urgent tasks to take advantage of more free time.")
        }
        
        // Check day after
        if dayAfterUtil < 0.4 && todayUtil > 0.8 {
            recommendations.append("💡 Day after tomorrow has more availability. Consider spreading work across all three days.")
        }
        
        // Positive feedback
        if todayUtil >= 0.5 && todayUtil <= 0.8 && abs(todayUtil - tomorrowUtil) < 0.2 {
            recommendations.append("✅ Workload is well-balanced between today and tomorrow.")
        }
        
        if recommendations.isEmpty {
            recommendations.append("✅ Schedule looks balanced.")
        }
        
        return (recommendations.joined(separator: "\n"), tasksToDefer, imbalanceSeverity)
    }
    
    // MARK: - Helper Functions
    
    private func getFixedCommitmentsForDay(
        user: User,
        weekday: Weekday,
        dayOffset: Int,
        now: Date
    ) -> [Event] {
        var events: [Event] = []
        
        // School hours
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
        
        // Work hours
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
        
        return events
    }
    
    private func dateForDay(_ hhmm: String, dayOffset: Int, now: Date) -> Date? {
        guard let baseDate = dateFromHHMM(hhmm) else { return nil }
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: dayOffset, to: baseDate)
    }
}

