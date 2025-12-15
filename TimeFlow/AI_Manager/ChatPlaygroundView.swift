//
//  ChatPlaygroundView.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/25/25.
//

import SwiftUI
import FirebaseAuth

func chatWithAI(prompt: String, model: String = "gpt-4o") async throws -> String {
    guard let user = Auth.auth().currentUser else {
        throw NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
    }

    let idToken = try await user.getIDToken()

    let url = URL(string: AppConfiguration.API.chatWithAI)!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

    let body = [
        "prompt": prompt,
        "model": model
    ]
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "Server error: \(errorString)"])
    }

    struct ChatResponse: Decodable {
        let content: String
    }

    let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
    return decoded.content
}



// MARK: - Public helper
func userInfoToSchedule(
    user: User,
    history: UserHistory,
    note: String,
    now: Date = Date(),
    preprocessingResult: PreprocessingResult? = nil
) async throws -> [Event] {

    // ----- 1. Build prompt --------------------------------------------------
    let prompt: String
    switch user.ageGroup {
    case .highSchool, .middleSchool:
        prompt = generateSchoolStudentSchedulePrompt(
                    user: user, history: history, note: note, now: now, preprocessingResult: preprocessingResult)
    case .college:
        prompt = generateCollegeStudentSchedulePrompt(
                    user: user, history: history, note: note, now: now, preprocessingResult: preprocessingResult)
    case .youngProfessional:
        prompt = generateYoungProSchedulePrompt(
                    user: user, history: history, note: note, now: now, preprocessingResult: preprocessingResult)
    }
    
//    print("---------------- PROMPT ----------------------")
//    print(prompt)
//    print("--------------------------------------")

    // ----- 2. Query AI ------------------------------------------------------
    let raw = try await chatWithAI(prompt: prompt, model: AppConfiguration.AIModel.scheduleModel)

    // ----- 3. Clean JSON ----------------------------------------------------
    let cleaned = raw
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "“", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: "```json", with: "")
        .replacingOccurrences(of: "```", with: "")

    // Grab first '[' … last ']' to be safe
    guard
        let firstBracket = cleaned.firstIndex(of: "["),
        let lastBracket  = cleaned.lastIndex(of: "]")
    else { throw ScheduleError.invalidJSON }

    let jsonString = String(cleaned[firstBracket...lastBracket])
    print("Cleaned JSON:", jsonString)

    guard let data = jsonString.data(using: .utf8) else {
        throw ScheduleError.invalidJSON
    }

    // ----- 4. Parse into [Event] -------------------------------------------
    // Using JSONSerialization so we can keep Event as‑is
    guard
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { throw ScheduleError.invalidJSON }

    let events: [Event] = array.compactMap { dict in
        guard
            let title  = dict["title"] as? String,
            let startS = dict["start"] as? String,
            let endS   = dict["end"]   as? String,
            let start  = dateFromHHMM(startS),
            let end    = dateFromHHMM(endS)
        else { return nil }

        let idStr = dict["id"] as? String ?? title
        let uuid = UUID(uuidString: idStr) ?? UUID()
        
        // Determine event type, color, and icon based on ID
        let (eventType, colorName, icon) = determineEventType(id: idStr, user: user)

        return Event(id: uuid,
                     start: start,
                     end: end,
                     title: title,
                     icon: icon ?? "circle",
                     eventType: eventType,
                     colorName: colorName)
    }
    
    return events
}

// MARK: - Event Type Determination
private func determineEventType(id: String, user: User) -> (EventType, String?, String?) {
    // If it's a UUID, search through user data
    if let uuid = UUID(uuidString: id) {
        // Check goals
        if let goal = user.goals.first(where: { $0.id == uuid }) {
            return (.goal, goal.colorName, goal.icon)
        }
        
        // Check recurring commitments
        if let commitment = user.recurringCommitments.first(where: { $0.id == uuid }) {
            return (.recurringCommitment, commitment.colorName, commitment.icon)
        }
        
        // Check assignments
        if user.assignments.contains(where: { $0.id == uuid }) {
            return (.assignment, "red", "doc.text.fill") // Default assignment color and icon
        }
        
        // Check tests
        if user.tests.contains(where: { $0.id == uuid }) {
            return (.testStudy, "yellow", "graduationcap.fill") // Default test color and icon
        }
        
        // Check college courses
        if let course = user.collegeCourses.first(where: { $0.id == uuid }) {
            return (.collegeClass, course.colorName, "book.fill") // Default college class icon
        }
        
        // Check work hours (for young professionals)
        if user.workHours.contains(where: { $0.id == uuid }) {
            return (.work, "orange", "briefcase.fill") // Default work color and icon
        }
        
        // If UUID not found in any data, default to other
        return (.other, "gray", "questionmark.circle")
    }
    
    // If it's not a UUID, check for specific meal strings and other categories
    let lowercaseId = id.lowercased()
    
    if lowercaseId == "breakfast" || lowercaseId == "lunch" || lowercaseId == "dinner" {
        let mealIcon: String
        switch lowercaseId {
        case "breakfast": mealIcon = "cup.and.saucer.fill"
        case "lunch": mealIcon = "fork.knife"
        case "dinner": mealIcon = "takeoutbag.and.cup.and.straw.fill"
        default: mealIcon = "fork.knife"
        }
        return (.meal, "purple", mealIcon)
    }
    
    if lowercaseId == "school" {
        return (.school, "teal", "building.2.fill") // Default school color and icon
    }
    
    if lowercaseId.contains("work") {
        return (.work, "orange", "briefcase.fill")
    }
    
    // Default to other for everything else
    return (.other, "gray", nil)
}

// MARK: - Errors
private enum ScheduleError: Error { case invalidJSON }

func generateSchoolStudentSchedulePrompt(
    user: User,
    history: UserHistory,
    note: String = "",
    now: Date = Date(),
    lookbackDays: Int = 3,
    preprocessingResult: PreprocessingResult? = nil
) -> String {

    let cal = Calendar.current
    
    let wakeTime = user.todaysAwakeHours?.wakeTime ?? user.awakeHours.wakeTime
    let hardBedtime = user.todaysAwakeHours?.sleepTime ?? user.awakeHours.sleepTime
    let softBedtime = { () -> String in
        let comps = hardBedtime.split(separator: ":").compactMap { Int($0) }
        guard comps.count == 2 else { return hardBedtime }
        let mins = comps[0] * 60 + comps[1] + 20       // +20 min cap
        return String(format: "%02d:%02d", (mins / 60) % 24, mins % 60)
    }()

    // MARK: — Summaries (same as before)
    let weekdayIdx = cal.component(.weekday, from: now)
    let weekday = Weekday.allCases[(weekdayIdx + 5) % 7]
    let isSchoolDay = weekday != .saturday && weekday != .sunday
    
    var goalsSummary: String {
        func effectivePerWeek(for goal: Goal) -> Int {
            switch goal.cadence {
            case .daily: return 7
            case .thriceWeekly: return 3
            case .weekly: return 1
            case .custom: return goal.customPerWeek ?? 0
            }
        }
        
        let activeGoals = user.goals.filter { $0.isActive }
        
        let sortedGoals = activeGoals.sorted { goal1, goal2 in
            let rem1 = effectivePerWeek(for: goal1) - goal1.daysCompletedThisWeek.count
            let rem2 = effectivePerWeek(for: goal2) - goal2.daysCompletedThisWeek.count
            return rem1 > rem2
        }
        
        let summaries = sortedGoals.map { goal in
            let activityTitle: String
            if goal.activity.lowercased() == goal.title.lowercased() {
                activityTitle = goal.activity
            } else {
                activityTitle = "\(goal.activity)-\(goal.title)"
            }
            
            let effectiveCount = effectivePerWeek(for: goal)
            let completedCount = goal.daysCompletedThisWeek.count
            let daysStr = goal.daysCompletedThisWeek.isEmpty ? "none" : goal.daysCompletedThisWeek.map { $0.rawValue }.joined(separator: ", ")
            let extraStr = goal.extraPreferenceInfo.isEmpty ? "" : " Extra preferences: \(goal.extraPreferenceInfo)."
            
            return "\(activityTitle) - The user wants to complete this activity \(effectiveCount) times per week and has already completed it \(completedCount) times this week on \(daysStr). The activity's duration is \(goal.durationMinutes) minutes. \(extraStr) ID: \(goal.id.uuidString)."
        }
        
        return summaries.joined(separator: "\n")
    }
    
    var assignmentsSummary: String {
        let incompleteAssignments = user.assignments.filter { !$0.completed }
        
        let sortedAssignments = incompleteAssignments.sorted { $0.dueDate < $1.dueDate }
        
        let summaries = sortedAssignments.map { assignment in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let dueDateStr = dateFormatter.string(from: assignment.dueDate)
            
            let extraStr = assignment.extraPreferenceInfo.isEmpty ? "" : " Extra preferences: \(assignment.extraPreferenceInfo)."
            
            return "Assignment Title: \(assignment.assignmentTitle) - \(assignment.classTitle). Due on \(dueDateStr). Estimated time left to complete: \(assignment.estimatedMinutesLeftToComplete) minutes. \(extraStr). ID: \(assignment.id.uuidString)."
        }
        
        return summaries.joined(separator: "\n")
    }
    
    var testsSummary: String {
        let unpreparedTests = user.tests.filter { !$0.prepared }
        
        let sortedTests = unpreparedTests.sorted { $0.date < $1.date }
        
        let summaries = sortedTests.map { test in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let testDateStr = dateFormatter.string(from: test.date)
            
            let extraStr = test.extraPreferenceInfo.isEmpty ? "" : test.extraPreferenceInfo
            
            return "Test: \(test.testTitle) - \(test.classTitle). Scheduled on \(testDateStr). Estimated study time left: \(test.studyMinutesLeft) minutes. \(extraStr). ID: \(test.id.uuidString)."
        }
        
        return summaries.joined(separator: "\n")
    }
    
    var recurringCommitmentsSummary: String {
        let now = Date()
        let weekdayComponent = cal.component(.weekday, from: now)
        
        let weekdayMap: [Int: Weekday] = [
            1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday,
            5: .thursday, 6: .friday, 7: .saturday
        ]
        
        guard let todayWeekday = weekdayMap[weekdayComponent] else {
            return "Error determining current weekday."
        }
        
        let todaysCommitments = user.recurringCommitments.filter {
            $0.cadence == .daily ||
            ($0.cadence == .weekdays && [.monday, .tuesday, .wednesday, .thursday, .friday].contains(todayWeekday)) ||
            ($0.cadence == .custom && $0.customDays.contains(todayWeekday))
        }
        
        if todaysCommitments.isEmpty {
            return "No commitments today."
        }
    
        let summaryLines = todaysCommitments
            .sorted { $0.startTime < $1.startTime }
            .map { commitment in
                let daysStr = commitment.cadence == .custom && !commitment.customDays.isEmpty
                    ? " on " + commitment.customDays.map { $0.rawValue }.joined(separator: ", ")
                    : ""
                return "Recurring Commitment: \(commitment.title). Cadence: \(commitment.cadence.rawValue)\(daysStr). Time: \(commitment.startTime) - \(commitment.endTime). ID: \(commitment.id.uuidString)."
            }

        return summaryLines.joined(separator: "\n")
    }
    
    var ngTimeSummary: String {
        // helper to turn "HH:mm" into a Date on `now`’s day
        func dateToday(from time: String) -> Date? {
            let comps = time.split(separator: ":").compactMap { Int($0) }
            guard comps.count == 2 else { return nil }
            var dc = cal.dateComponents([.year, .month, .day], from: now)
            dc.hour   = comps[0]
            dc.minute = comps[1]
            return cal.date(from: dc)
        }

        guard
            let wakeDate = dateToday(from: wakeTime),
            wakeDate < now            // nothing to do if we generated before wake‑up
        else { return "" }

        // ---- Collect TODAY’s fixed intervals that ended (or started) before `now` ----
        var intervals: [(start: Date, end: Date)] = []

        // school hours
        if isSchoolDay,
           let s = dateToday(from: user.schoolHours.startTime),
           let e = dateToday(from: user.schoolHours.endTime) {
            intervals.append((start: s, end: min(e, now)))
        }

        // today’s recurring commitments
        for c in user.recurringCommitments {
            let isToday =
                c.cadence == .daily ||
                (c.cadence == .weekdays && [.monday,.tuesday,.wednesday,.thursday,.friday].contains(weekday)) ||
                (c.cadence == .custom && c.customDays.contains(weekday))
            guard isToday,
                  let s = dateToday(from: c.startTime),
                  let e = dateToday(from: c.endTime),
                  s < now                         // ignore ones entirely in the future
            else { continue }
            intervals.append((start: s, end: min(e, now)))
        }

        // merge overlaps & sort
        intervals.sort { $0.start < $1.start }
        var merged: [(start: Date, end: Date)] = []
        for iv in intervals {
            if let last = merged.last, iv.start <= last.end {
                merged[merged.count - 1].end = max(last.end, iv.end)
            } else {
                merged.append(iv)
            }
        }

        // ---- Build NGTime gaps (5‑minute buffers)  ----
        var ng: [(Date,Date)] = []
        var cursor = wakeDate
        for iv in merged {
            let gapEnd   = iv.start.addingTimeInterval(-5*60)     // leave 5 min before
            if gapEnd > cursor { ng.append((cursor, gapEnd)) }
            cursor = iv.end.addingTimeInterval( 5*60)             // leave 5 min after
        }
        if cursor < now.addingTimeInterval(-5*60) {
            ng.append((cursor, now.addingTimeInterval(-5*60)))
        }
        guard !ng.isEmpty else { return "" }

        // stringify
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return ng.enumerated().map { idx, block in
            "Recurring Commitment: NGTime. Cadence: one‑off. Time: \(fmt.string(from:block.0)) - \(fmt.string(from:block.1)). ID: NGTime-\(idx)."
        }.joined(separator: "\n")
    }

    // MARK: — Prompt
    let prompt = """
    You are an elite scheduling assistant.

    ## TODAY
    • Schedule window: **\(wakeTime)** → soft bedtime **\(hardBedtime)** (may extend to **\(softBedtime)** if needed)

    ## USER DATA
    • School hours: \(user.schoolHours.startTime)-\(user.schoolHours.endTime) \(isSchoolDay ? "(school day)" : "(Weekend, user has NO school)")

    • Today's commitments:
    \(recurringCommitmentsSummary)
    \(ngTimeSummary)
    
    
    • Active goals:
    \(goalsSummary)
    
    
    • Pending assignments:
    \(assignmentsSummary)
    
    
    • Pending tests:
    \(testsSummary)
    

    ## USER NOTE
    "\(note)"

    \(preprocessingResult != nil ? formatAlgorithmicContext(preprocessingResult: preprocessingResult!, now: now) : "")

    ## OBJECTIVE
    Build the most productive, balanced and thought out schedule from the current time until bedtime.

    ## RULES
    1. **Priority** Prioritize Closely Due Assignments and Tests First, then Goals, then assignments that are less urgent.
    2. **Gaps** Leave at least a 5 min gaps or more time if you see necessary between each activity; **no explicit Break/Leisure events**.
    3. **Meals** Breakfast 30 min (if ahead), Dinner 30 min 18:00‑20:00; \(isSchoolDay ? "Lunch in school – don't add." : "Add Lunch 30 min ±1:15.")
    4. **Titles** must be specific; no “Study”/“Work” fillers.
    5. **Bedtime** Aim to finish by \(hardBedtime), **but** if need more time for assignments extend bedtime up to **\(softBedtime)**.  
       Always preserve ≥ 6 h sleep (i.e., do not schedule past 00:30 if wake is 07:00). 
    6. *Need more time** *You may extend the user’s bedtime by up to 20 minutes (e.g., 23:20 instead of 23:00) when doing so lets you fit a beneficial, non‑urgent activity—such as a goal session or an optional assignment—that would otherwise be left out.
    7. **Do not schedule the same goal twice in one day.**
    8. No overlaps; free blocks may remain unscheduled.

    ## OUTPUT (STRICT)
    Return **only** a JSON array, e.g.:
    [
      { "title": "School", "start": "8:30", "end": "15:00", "id": "School" }, ← used Event Title
      { "title": "Soccer Practive", "start": "15:30", "end": "17:15", "id": "71778cfa-4120-41e5-a7c4-0366b57463f4" }, ← used given UUID
      { "title": "Math Worksheet - AP Calculus", "start": "17:45", "end": "18:30", "id": "71778cfa-4120-41e5-a7c4-0366b57463f4" } ← used given UUID
    ]

    • "id" — if the event already has a UUID in the data above, use it; otherwise set "id" to the event’s title.
    """

    return prompt
}

func generateCollegeStudentSchedulePrompt(
    user: User,
    history: UserHistory,
    note: String = "",
    now: Date = Date(),
    lookbackDays: Int = 3,
    preprocessingResult: PreprocessingResult? = nil
) -> String {

    let cal = Calendar.current
    
    let wakeTime = user.todaysAwakeHours?.wakeTime ?? user.awakeHours.wakeTime
    let hardBedtime = user.todaysAwakeHours?.sleepTime ?? user.awakeHours.sleepTime
    let softBedtime = { () -> String in
        let comps = hardBedtime.split(separator: ":").compactMap { Int($0) }
        guard comps.count == 2 else { return hardBedtime }
        let mins = comps[0] * 60 + comps[1] + 20       // +20 min cap
        return String(format: "%02d:%02d", (mins / 60) % 24, mins % 60)
    }()

    // Weekday helpers
    let weekdayIdx = cal.component(.weekday, from: now)
    let weekdayEnum = Weekday.allCases[(weekdayIdx + 5) % 7]

    // ---------- College course commitments today ----------
    let todaysCourses = user.collegeCourses
        .filter { $0.day == weekdayEnum }
        .sorted { $0.startTime < $1.startTime }

    let coursesSummary = todaysCourses.isEmpty
        ? "None"
        : todaysCourses.map {
            "– \($0.name) \($0.startTime)-\($0.endTime) (ID: \($0.id.uuidString))"
          }.joined(separator: "\n")

    // ---------- Goals summary (same logic as before) ----------
    func effectivePerWeek(for g: Goal) -> Int {
        switch g.cadence {
        case .daily: 7
        case .thriceWeekly: 3
        case .weekly: 1
        case .custom: g.customPerWeek ?? 0
        }
    }
    let goalsSummary = user.goals
        .filter { $0.isActive }
        .sorted {
            effectivePerWeek(for: $0) - $0.daysCompletedThisWeek.count >
            effectivePerWeek(for: $1) - $1.daysCompletedThisWeek.count
        }
        .map { g -> String in
            let remaining = effectivePerWeek(for: g) - g.daysCompletedThisWeek.count
            let actTitle = g.activity.lowercased() == g.title.lowercased()
                ? g.activity : "\(g.activity)-\(g.title)"
            let prefs = g.extraPreferenceInfo.isEmpty ? "" : "User prefers: \(g.extraPreferenceInfo)."
            return "\(actTitle) – \(g.durationMinutes) min, needs \(max(0,remaining)) this week.\(prefs) ID: \(g.id.uuidString)."
        }.joined(separator: "\n").ifEmpty("None")

    // ---------- Assignments / tests summaries (same pattern) ----------
    func daysLeft(to d: Date) -> String {
        "\(max(0, Int(d.timeIntervalSince(now)/86_400))) d"
    }
    let assignmentsSummary = user.assignments.filter { !$0.completed }
        .sorted { $0.dueDate < $1.dueDate }
        .map {
            let prefs = $0.extraPreferenceInfo.isEmpty ? "" : " Prefers: \($0.extraPreferenceInfo)."
            return "– \($0.assignmentTitle) (\($0.classTitle)), due \(daysLeft(to:$0.dueDate)), ~\($0.estimatedMinutesLeftToComplete) min left,\(prefs) ID: \($0.id.uuidString)"
        }.joined(separator: "\n").ifEmpty("None")

    let testsSummary = user.tests.filter { !$0.prepared }
        .sorted { $0.date < $1.date }
        .map {
            let prefs = $0.extraPreferenceInfo.isEmpty ? "" : " Prefers: \($0.extraPreferenceInfo)."
            return "– \($0.testTitle) (\($0.classTitle)) on \(daysLeft(to:$0.date)), ~\($0.studyMinutesLeft) min study left.\(prefs) ID: \($0.id.uuidString)"
        }.joined(separator: "\n").ifEmpty("None")

    // ---------- Recurring commitments (clubs, work, etc.) ----------
    let todaysCommitments = user.recurringCommitments
        .filter {
            switch $0.cadence {
            case .daily: true
            case .weekdays: weekdayEnum != .saturday && weekdayEnum != .sunday
            case .custom: $0.customDays.contains(weekdayEnum)
            }
        }.map {
            "– \($0.title) \($0.startTime)-\($0.endTime) (ID: \($0.id.uuidString))"
        }.sorted().joined(separator: "\n").ifEmpty("None")

    let ngTimeSummary: String = {
        // helper: "HH:mm" -> Date today
        func dateToday(_ time: String) -> Date? {
            let comps = time.split(separator: ":").compactMap { Int($0) }
            guard comps.count == 2 else { return nil }
            var dc = cal.dateComponents([.year,.month,.day], from: now)
            dc.hour = comps[0]; dc.minute = comps[1]
            return cal.date(from: dc)
        }

        guard
            let wakeDate = dateToday(wakeTime),
            wakeDate < now                                // skip if before wake‑up
        else { return "" }

        // collect fixed intervals (TODAY’s courses + recurring commitments)
        var intervals: [(Date,Date)] = []

        // today’s courses
        for c in todaysCourses {
            if let s = dateToday(c.startTime),
               let e = dateToday(c.endTime),
               s < now {
                intervals.append((s, min(e,now)))
            }
        }

        // today’s recurring commitments
        for rc in user.recurringCommitments {
            let happensToday: Bool = {
                switch rc.cadence{
                case .daily: true
                case .weekdays: weekdayEnum != .saturday && weekdayEnum != .sunday
                case .custom: rc.customDays.contains(weekdayEnum)
                }
            }()
            guard happensToday,
                  let s = dateToday(rc.startTime),
                  let e = dateToday(rc.endTime),
                  s < now
            else { continue }
            intervals.append((s, min(e,now)))
        }

        // merge overlapping intervals
        intervals.sort { $0.0 < $1.0 }
        var merged: [(Date,Date)]=[]
        for iv in intervals{
            if let last = merged.last, iv.0 <= last.1 {
                merged[merged.count-1].1 = max(last.1, iv.1)
            } else {
                merged.append(iv)
            }
        }

        // build NGTime gaps (leave 5‑minute buffers)
        var ng: [(Date,Date)]=[]
        var cursor = wakeDate
        for iv in merged{
            let gapEnd = iv.0.addingTimeInterval(-5*60)
            if gapEnd > cursor { ng.append((cursor,gapEnd)) }
            cursor = iv.1.addingTimeInterval(5*60)
        }
        if cursor < now.addingTimeInterval(-5*60) {
            ng.append((cursor, now.addingTimeInterval(-5*60)))
        }
        guard !ng.isEmpty else { return "" }

        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        return ng.enumerated().map { idx, block in
            "– NGTime \(fmt.string(from:block.0))-\(fmt.string(from:block.1)) (ID: NGTime-\(idx))"
        }.joined(separator:"\n")
    }()
    
    // MARK: — Prompt
    let prompt = """
    You are an elite scheduling assistant for college students.

    ## TODAY
    • Schedule window: **\(wakeTime)** → bedtime **\(hardBedtime)** (may extend to **\(softBedtime)** if rules allow)

    ## USER DATA
    • Wake/Sleep: \(wakeTime)‑\(hardBedtime) (≥ 6 h sleep must remain)
    • College courses today:
    \(coursesSummary)

    • Today's commitments (clubs, part‑time work, etc.):
    \(todaysCommitments)
    \(ngTimeSummary)

    • Active goals:
    \(goalsSummary)

    • Pending assignments:
    \(assignmentsSummary)

    • Pending tests:
    \(testsSummary)

    ## USER NOTE
    "\(note)"

    \(preprocessingResult != nil ? formatAlgorithmicContext(preprocessingResult: preprocessingResult!, now: now) : "")

    ## OBJECTIVE
    Build the most productive, balanced and thought out schedule from the current time until bedtime.

    ## RULES
    1. Prioritize Closely Due Assignments and Tests First, then Goals, then assignments that are less urgent.
    2. Leave at least a 5 min gaps or more time if you see necessary between each activity; **no explicit Break/Leisure events**.
    3. **Meals**  
       • Breakfast 30 min if before first task.  
       • **Lunch** 40 min if a ≥ 60 min gap appears 11:30‑15:00.  
       • Dinner 30 min 18:00‑20:00.
    4. Titles must be specific; no “Study”/“Work” fillers.
    5. Aim to finish by \(hardBedtime), **but** if need more time for assignments extend bedtime up to **\(softBedtime)**.  
       Always preserve ≥ 7 h sleep (i.e., do not schedule past 00:00 if wake is 07:00). 
    6. You may extend the user’s bedtime by up to 20 minutes (e.g., 23:20 instead of 23:00) when doing so lets you fit a beneficial, non‑urgent activity—such as a goal session or an optional assignment—that would otherwise be left out.
    7. **Do not schedule the same goal twice in one day.**
    8. No overlaps; free blocks may remain unscheduled.

    ## OUTPUT (STRICT)
    Return **only** a JSON array, e.g.:
    [
      { "title": "Linear Algebra Worksheet", "start": "16:10", "end": "17:00", "id": "71778cfa-4120-41e5-a7c4-0366b57463f4" } ← used given UUID
    ]

    • "id" — if the event already has a UUID in the data above, use it; otherwise set "id" to the event’s title.
    """

    return prompt
}

func generateYoungProSchedulePrompt(
    user: User,
    history: UserHistory,
    note: String = "",
    now: Date = Date(),
    lookbackDays: Int = 3,
    preprocessingResult: PreprocessingResult? = nil
) -> String {

    guard user.ageGroup == .youngProfessional else {
        return "ERROR: user.ageGroup must be .youngProfessional"
    }

    // ---- Time helpers ------------------------------------------------------
    let cal = Calendar.current
    let bump = (5 - (cal.component(.minute, from: now) % 5)) % 5
    let startDate = cal.date(byAdding: .minute, value: bump, to: now)!
    let hhmm: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
    let startHHMM = hhmm.string(from: startDate)

    
    let hardBedtime = user.todaysAwakeHours?.sleepTime ?? user.awakeHours.sleepTime
    let softBedtime = { () -> String in
        let comps = hardBedtime.split(separator: ":").compactMap { Int($0) }
        guard comps.count == 2 else { return hardBedtime }
        let mins = comps[0] * 60 + comps[1] + 20       // +20 min cap
        return String(format: "%02d:%02d", (mins / 60) % 24, mins % 60)
    }()

    // ---- Work block today --------------------------------------------------
    let weekdayIdx = cal.component(.weekday, from: now)
    let weekday    = Weekday.allCases[(weekdayIdx + 5) % 7]

    let todaysWork = user.workHours.first { $0.day == weekday && $0.enabled }
    let workSummary = todaysWork == nil
        ? "None (day off)"
        : "\(todaysWork!.startTime)-\(todaysWork!.endTime)"

    let hasWorkToday = todaysWork != nil

    // ---- Goals summary (same as before) ------------------------------------
    func effectivePerWeek(_ g:Goal)->Int{
        switch g.cadence{case .daily:7;case .thriceWeekly:3;case .weekly:1;case .custom:g.customPerWeek ?? 0}
    }
    let goalsSummary = user.goals.filter{$0.isActive}
        .sorted{
            effectivePerWeek($0)-$0.daysCompletedThisWeek.count >
            effectivePerWeek($1)-$1.daysCompletedThisWeek.count
        }
        .map{ g in
            let remain = effectivePerWeek(g)-g.daysCompletedThisWeek.count
            let prefs  = g.extraPreferenceInfo.isEmpty ? "" : " Prefers: \(g.extraPreferenceInfo)."
            let name   = g.activity.lowercased()==g.title.lowercased() ? g.activity : "\(g.activity)-\(g.title)"
            return "\(name) – \(g.durationMinutes) min, needs \(max(0,remain)) this week.\(prefs) ID: \(g.id.uuidString)"
        }.joined(separator:"\n").ifEmpty("None")

    // ---- Recurring commitments --------------------------------------------
    let todaysCommitments = user.recurringCommitments.filter{
        switch $0.cadence{
        case .daily: true
        case .weekdays: [.monday,.tuesday,.wednesday,.thursday,.friday].contains(weekday)
        case .custom: $0.customDays.contains(weekday)
        }
    }.sorted{$0.startTime<$1.startTime}
     .map{ "– \($0.title) \($0.startTime)-\($0.endTime) (ID:\($0.id.uuidString))" }
     .joined(separator:"\n").ifEmpty("None")
    
    let ngTimeSummary: String = {
        // Wake‑up time (string like "07:00")
        let wakeTime = user.todaysAwakeHours?.wakeTime ?? user.awakeHours.wakeTime

        // convert "HH:mm" -> Date (today)
        func dateToday(_ time: String) -> Date? {
            let comps = time.split(separator: ":").compactMap { Int($0) }
            guard comps.count == 2 else { return nil }
            var dc = cal.dateComponents([.year,.month,.day], from: now)
            dc.hour = comps[0]; dc.minute = comps[1]
            return cal.date(from: dc)
        }

        guard
            let wakeDate = dateToday(wakeTime),
            wakeDate < now                                        // skip if before wake‑up
        else { return "" }

        // fixed intervals before `now`
        var intervals:[(Date,Date)] = []

        // today’s work block
        if let w = todaysWork,
           let s = dateToday(w.startTime),
           let e = dateToday(w.endTime),
           s < now {
            intervals.append((s, min(e,now)))
        }

        // today’s recurring commitments
        for rc in user.recurringCommitments {
            let happensToday: Bool = {
                switch rc.cadence{
                case .daily: true
                case .weekdays: [.monday,.tuesday,.wednesday,.thursday,.friday].contains(weekday)
                case .custom: rc.customDays.contains(weekday)
                }
            }()
            guard happensToday,
                  let s = dateToday(rc.startTime),
                  let e = dateToday(rc.endTime),
                  s < now else { continue }
            intervals.append((s, min(e,now)))
        }

        // merge overlapping intervals
        intervals.sort{ $0.0 < $1.0 }
        var merged:[(Date,Date)]=[]
        for iv in intervals{
            if let last = merged.last, iv.0 <= last.1 {
                merged[merged.count-1].1 = max(last.1, iv.1)
            } else {
                merged.append(iv)
            }
        }

        // build NGTime gaps (leave 5‑minute buffers)
        var ng:[(Date,Date)]=[]
        var cursor = wakeDate
        for iv in merged{
            let gapEnd = iv.0.addingTimeInterval(-5*60)
            if gapEnd > cursor { ng.append((cursor,gapEnd)) }
            cursor = iv.1.addingTimeInterval(5*60)
        }
        if cursor < now.addingTimeInterval(-5*60) {
            ng.append((cursor, now.addingTimeInterval(-5*60)))
        }
        guard !ng.isEmpty else { return "" }

        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        return ng.enumerated().map { idx, block in
            "– NGTime \(fmt.string(from:block.0))-\(fmt.string(from:block.1)) (ID: NGTime-\(idx))"
        }.joined(separator:"\n")
    }()

    // ---- Prompt ------------------------------------------------------------
    let prompt = """
    You are an elite scheduling assistant for young professionals.

    ## TODAY
    • Current time: \(ISO8601DateFormatter().string(from: now))
    • Schedule window: **\(startHHMM)** → bedtime **\(hardBedtime)** (may extend to **\(softBedtime)** if allowed)

    ## USER DATA
    • Now/Sleep: \(startHHMM)‑\(hardBedtime) (≥ 6 h sleep required)
    • Work hours today: \(workSummary)
    • Recurring commitments:
    \(todaysCommitments)
    \(ngTimeSummary)
    
    • Active goals:
    \(goalsSummary)

    ## USER NOTE
    "\(note)"

    \(preprocessingResult != nil ? formatAlgorithmicContext(preprocessingResult: preprocessingResult!, now: now) : "")

    ## OBJECTIVE
    Build the most productive, balanced and thought out schedule from the current time until bedtime.

    ## RULES
    1. **Fixed commitments first** – schedule the work block (if any) and recurring commitments at their exact times.
    2. **Gaps** Leave at least a 5 min gaps or more time if you see necessary between each activity; **no explicit Break/Leisure events**.
    3. **Meals**  
           - Breakfast 30 min if before first task.  
           - \(hasWorkToday ? "*No scheduled Lunch – user manages lunch during work.*" : "Lunch 30 min around 1:00 (only on non‑workdays).")  
           - Dinner 30 min between 18:00‑20:00.
    4. **Titles** must be specific; no “Study”/“Work” fillers.
    5. **Bedtime** Aim to finish by \(hardBedtime), **but** if need more time for assignments extend bedtime up to **\(softBedtime)**.  
       Always preserve ≥ 6 h sleep (i.e., do not schedule past 00:30 if wake is 07:00). 
    6. *Need more time** *You may extend the user’s bedtime by up to 20 minutes (e.g., 23:20 instead of 23:00) when doing so lets you fit a beneficial, non‑urgent activity—such as a goal session or an optional assignment—that would otherwise be left out.
    7. **Do not schedule the same goal twice in one day.**
    8. No overlaps; free blocks may remain unscheduled.

    ## OUTPUT (STRICT)
    Return **only** a JSON array, e.g.:
    [
      { "title": "Evening Run", "start": "18:20", "end": "18:50", "id": "71778cfa-4120-41e5-a7c4-0366b57463f4" } ← used given UUID
    ]

    • "id" — if the event already has a UUID in the data above, use it; otherwise set "id" to the event’s title.
    """

    return prompt
}



// MARK: — Algorithmic Context Formatter

private func formatAlgorithmicContext(preprocessingResult: PreprocessingResult, now: Date) -> String {
    var context = "\n## ALGORITHMIC INSIGHTS & RECOMMENDATIONS\n"
    
    // Time slots summary
    let todaySlots = preprocessingResult.availableTimeSlots.filter { $0.dayOffset == 0 && $0.start >= now }
    let tomorrowSlots = preprocessingResult.availableTimeSlots.filter { $0.dayOffset == 1 }
    
    if !todaySlots.isEmpty {
        let totalMinutes = Int(todaySlots.reduce(0) { $0 + $1.duration } / 60)
        let topSlots = todaySlots.prefix(3).map { slot in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let startStr = formatter.string(from: slot.start)
            let endStr = formatter.string(from: slot.end)
            let duration = Int(slot.duration / 60)
            return "\(startStr)-\(endStr) (\(duration) min, quality: \(Int(slot.qualityScore * 100))%)"
        }
        context += "• **Today's available time**: ~\(totalMinutes) minutes in \(todaySlots.count) time slots\n"
        context += "• **Best time slots today**: \(topSlots.joined(separator: ", "))\n"
    }
    
    if !tomorrowSlots.isEmpty {
        let totalMinutes = Int(tomorrowSlots.reduce(0) { $0 + $1.duration } / 60)
        context += "• **Tomorrow's available time**: ~\(totalMinutes) minutes in \(tomorrowSlots.count) time slots\n"
    }
    
    // Task breakdowns
    if !preprocessingResult.taskBreakdowns.isEmpty {
        context += "\n• **Suggested task breakdowns**:\n"
        let topBreakdowns = preprocessingResult.taskBreakdowns.prefix(5)
        for chunk in topBreakdowns {
            let dayHint = chunk.suggestedDay == 0 ? " (suggested for today)" : chunk.suggestedDay == 1 ? " (can defer to tomorrow)" : " (flexible)"
            let deferHint = chunk.canDefer ? " [DEFERRABLE]" : ""
            context += "  - \(chunk.title): \(chunk.durationMinutes) min, priority: \(Int(chunk.priority * 100))%\(dayHint)\(deferHint)\n"
        }
    }
    
    // Workload recommendations
    if !preprocessingResult.workloadRecommendations.isEmpty {
        context += "\n• **Workload balance**:\n"
        let lines = preprocessingResult.workloadRecommendations.components(separatedBy: "\n")
        for line in lines where !line.isEmpty {
            context += "  \(line)\n"
        }
    }
    
    // Additional guidance
    context += "\n**IMPORTANT GUIDANCE**:\n"
    context += "1. **DO NOT jam pack today** if tomorrow has significantly more free time. Defer non-urgent tasks (marked as DEFERRABLE) to tomorrow.\n"
    context += "2. Use the suggested task breakdowns to split large assignments into manageable chunks.\n"
    context += "3. Prioritize high-quality time slots (morning/early afternoon) for important work.\n"
    context += "4. Balance workload across days - if today is >80% full and tomorrow is <40% full, defer some tasks.\n"
    
    return context
}

// MARK: — Tiny helper
private extension String {
    func ifEmpty(_ alt: String) -> String { isEmpty ? alt : self }
}
