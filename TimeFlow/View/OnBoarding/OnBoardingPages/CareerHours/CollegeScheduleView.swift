//
//  CollegeScheduleView.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/28/25.
//

import SwiftUI
import UIKit

struct CollegeScheduleView: View {
    
    @Binding var courses: [CollegeCourse]
    let themeColor: Color
    
    @State private var editing: CollegeCourse? = nil
    @State private var showSheet = false
    
    private let hourHeight: CGFloat = 38
    private let card = Color(red: 0.13, green: 0.13, blue: 0.15)
    

    private let weekdays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]
    
    
    var onContinue: () -> Void = {}
    
    init(courses: Binding<[CollegeCourse]>, themeColor: Color, onContinue: @escaping () -> Void = {}) {
        self._courses = courses
        self.themeColor = themeColor
        self.onContinue = onContinue
        UIScrollView.appearance().bounces = false
    }
    
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            //background
            LinearGradient(
                colors: [
                    AppTheme.Colors.background,
                    AppTheme.Colors.secondary.opacity(0.3),
                    AppTheme.Colors.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                header
                
                calendarPanel
                    .padding(.horizontal, 8)
                    .scaleEffect(animateContent ? 1.0 : 0.8)
                    .opacity(animateContent ? 1.0 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
                
                addButton
                    .scaleEffect(animateContent ? 1.0 : 0.8)
                    .opacity(animateContent ? 1.0 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
                
                Button(action: onContinue) {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(courses.isEmpty ? Color.gray.opacity(0.4) : themeColor)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .disabled(courses.isEmpty)
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            progressToolbar(currentStep: 2) {
                onContinue()
            }
        }
        .sheet(isPresented: $showSheet) {
            ClassSheet(existing: $editing, accent: themeColor) { save($0) }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation {
                animateContent = true
            }
        }
    }
}

// MARK: Calendar
private extension CollegeScheduleView {
    
    var calendarPanel: some View {
        VStack(spacing: 0) {
            weekdayHeader
            ScrollView(showsIndicators: true) {
                calendarGrid
                    .frame(height: hourHeight * 18)   // 6 AM→12 AM
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(card)
                .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
        )
    }
    
    var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdays) { day in
                Text(abbr(for: day))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .background(card.opacity(0.9))
    }
    
    private func abbr(for day: Weekday) -> String {
        switch day {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
    
    var calendarGrid: some View {
        ZStack(alignment: .topLeading) {
            gridLines
            classBlocks
        }
    }
    
    var gridLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<18) { _ in
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                Spacer().frame(height: hourHeight - 1)
            }
        }
        .overlay(
            HStack(spacing: 0) {
                ForEach(weekdays) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1)
                    Spacer()
                }
            }
        )
    }
    
    var classBlocks: some View {
        GeometryReader { geo in

            ForEach($courses) { $course in    // binding array → Binding<CollegeCourse>
                let current = $course.wrappedValue

                if let colIndex = weekdays.firstIndex(of: current.day) {
                    let rect  = frame(for: current)
                    let colW  = geo.size.width / CGFloat(weekdays.count)

                    ClassBlockView(
                        course: current,
                        width:  colW - 4,
                        frame:  (top: rect.minY, height: rect.height),
                        colX:   CGFloat(colIndex) * colW
                    )
                    .onTapGesture {
                        editing   = current          // edit a *copy* in your sheet
                        showSheet = true
                    }
                }
            }
        }
        .clipped()
    }
    
    private struct ClassBlockView: View {
        let course: CollegeCourse
        let width:  CGFloat
        let frame:  (top: CGFloat, height: CGFloat)
        let colX:   CGFloat

        var body: some View {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.palette(course.colorName))
                .overlay(
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.name).font(.caption).bold()
                        Text(time(from: course.startTime) + " – " + time(from: course.endTime))
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .padding(4),
                    alignment: .topLeading
                )
                .frame(width: width, height: frame.height - 2)
                .position(x: colX + width / 2,
                          y: frame.top + frame.height / 2)
        }

        private func time(from hhmm: String) -> String {
            guard let d = dateFromHHMM(hhmm) else { return hhmm }
            return DateFormatter.localizedString(from: d,
                                          dateStyle: .none,
                                          timeStyle: .short)
        }
    }
    
    func frame(for course: CollegeCourse) -> CGRect {
        // convert HH:mm strings to fractional hour values
        let startH = fractionalHours(from: course.startTime)
        let endH   = fractionalHours(from: course.endTime)

        let top    = CGFloat(startH - 6) * hourHeight
        let height = CGFloat(endH - startH) * hourHeight
        return CGRect(x: 0, y: top, width: 0, height: height)
    }
    
    private func fractionalHours(from hhmm: String) -> Double {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Double(parts[0]), let m = Double(parts[1]) else { return 0 }
        return h + m / 60.0
    }
}

// MARK: Fixed UI
private extension CollegeScheduleView {
    
    var header: some View {
        VStack(spacing: 6) {
            Text("Add your classes")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Tap + to insert · tap block to edit")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal)
        .opacity(animateContent ? 1.0 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.easeOut(duration: 0.8), value: animateContent)
    }
    
    var addButton: some View {
        Button {
            editing = nil
            showSheet = true
        } label: {
            Label("Add class", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(themeColor)
                .foregroundColor(.white)
                .cornerRadius(14)
                .padding(.horizontal)
        }
    }
    
}


struct ClassSheet: View {
    // MARK: ‑ Dependencies
    @Environment(\.dismiss) private var dismiss

    @Binding var existing: CollegeCourse?
    let accent: Color
    let onSave: (CollegeCourse) -> Void

    // MARK: ‑ Form State
    @State private var name = ""
    @State private var selectedWeekdays: Set<Weekday> = [.monday]
    @State private var start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
    @State private var end   = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now)!
    @State private var colorName = "blue"
    @State private var showDeleteAlert = false

    // MARK: ‑ Constants
    private let palette: [String] = ["red","orange","yellow","green","mint","teal","cyan","blue","indigo","purple","pink"]
    private let weekdays: [Weekday] = [.monday,.tuesday,.wednesday,.thursday,.friday]

    // MARK: ‑ Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    NameSection
                    ScheduleSection
                    ColorSection
                    if existing != nil { DeleteSection }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .background(Color(.systemBackground))
            .navigationTitle(existing == nil ? "New Class" : "Edit Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .foregroundStyle(.white.opacity(0.7))
                        .fontWeight(.semibold)
                        .disabled(!isFormValid)
                }
            }
        }
        .task { if let course = existing { load(course) } }
        .preferredColorScheme(.dark)
        .alert("Delete This Class?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                guard let course = existing else { return }
                onSave(course.deletedCopy)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: ‑ Sub‑views
private extension ClassSheet {

    var NameSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Course Name")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Linear Algebra", text: $name)
                    .textInputAutocapitalization(.words)
                    .font(.body)
            }
        }
    }

    var ScheduleSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Label("Schedule", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                // Multiple Days Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Days")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 12) {
                        ForEach(weekdays, id: \.self) { day in
                            Button {
                                if selectedWeekdays.contains(day) {
                                    selectedWeekdays.remove(day)
                                } else {
                                    selectedWeekdays.insert(day)
                                }
                            } label: {
                                Text(dayAbbreviation(day))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(selectedWeekdays.contains(day) ? .white : .primary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedWeekdays.contains(day) ? accent : Color(.secondarySystemFill))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedWeekdays.contains(day) ? accent : Color(.separator), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Time Pickers
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        DatePicker("Start", selection: $start,
                                   in: timeRange,
                                   displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("End")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        DatePicker("End", selection: $end,
                                   in: timeRange,
                                   displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    var ColorSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Label("Color", systemImage: "paintpalette")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 6), spacing: 16) {
                    ForEach(palette, id: \.self) { name in
                        Circle()
                            .fill(AppTheme.ActivityColors.palette(name))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(name == colorName ? accent : .clear, lineWidth: 3)
                            )
                            .contentShape(Circle())
                            .onTapGesture { colorName = name }
                            .accessibilityLabel(Text(name))
                    }
                }
            }
        }
    }

    var DeleteSection: some View {
        Card {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete Class", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: ‑ Helpers
private extension ClassSheet {

    var timeRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return start...end
    }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && 
        end > start && 
        !selectedWeekdays.isEmpty
    }
    
    private func dayAbbreviation(_ day: Weekday) -> String {
        switch day {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }

    func load(_ course: CollegeCourse) {
        name = course.name
        selectedWeekdays = [course.day]  // When editing, only show the current day
        colorName = course.colorName
        start = dateFromHHMM(course.startTime) ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
        end = dateFromHHMM(course.endTime) ?? Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now)!
    }

    func save() {
        let courseName = name.trimmingCharacters(in: .whitespaces)
        let startTime = start.hhmmString
        let endTime = end.hhmmString
        
        // If editing an existing course, just update it
        if let existing = existing {
            let updatedCourse = CollegeCourse(
                id: existing.id,
                name: courseName,
                day: existing.day,  // Keep the original day
                startTime: startTime,
                endTime: endTime,
                colorName: colorName
            )
            onSave(updatedCourse)
        } else {
            // If creating new, create separate courses for each selected day
            for day in selectedWeekdays {
                let newCourse = CollegeCourse(
                    id: UUID(),  // Each day gets a unique ID
                    name: courseName,
                    day: day,
                    startTime: startTime,
                    endTime: endTime,
                    colorName: colorName
                )
                onSave(newCourse)
            }
        }
        
        dismiss()
    }
}

// MARK: ‑ Card Wrapper
private struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.1), radius: 6, x: 0, y: 2)
            )
    }
}

// MARK: ‑ Convenience Extensions
private extension CollegeCourse {
    /// A shallow copy with zero‑values used when deleting a course.
    var deletedCopy: CollegeCourse {
        .init(id: id, name: "", day: .monday, startTime: "00:00", endTime: "00:00", colorName: "accent")
    }
}


private extension CollegeScheduleView {
    func save(_ c: CollegeCourse) {
        if let i = courses.firstIndex(where: { $0.id == c.id }) {
            if c.name.isEmpty { 
                courses.remove(at: i) 
            } else { 
                courses[i] = c 
            }
        } else { 
            courses.append(c) 
        }
    }
}

#Preview {
    CollegeScheduleView(courses: .constant([]), themeColor: .blue)
}