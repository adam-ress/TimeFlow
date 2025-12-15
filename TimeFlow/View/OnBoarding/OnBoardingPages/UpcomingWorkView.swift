//
//  UpcomingWorkView.swift
//  TimeFlow
//
//  Created by Adam Ress on 7/11/25.
//

import SwiftUI

// MARK: – Main screen with consistent header style
struct UpcomingWorkView: View {
    @Binding var assignments: [Assignment]
    @Binding var tests: [Test]
    @Binding var classes: [String]
    
    @State private var selectedTab: Tab = .assignments
    @State private var showAddSheet = false
    @State private var showClassManager = false
    @State private var editingAssignment: Assignment?
    @State private var editingTest: Test?
    
    let themeColor: Color
    
    var onContinue: () -> Void = {}
    
    enum Tab: String, CaseIterable {
        case assignments = "Assignments"
        case tests = "Tests"
    }
    
    @State private var animateContent = false
    
    var body: some View {
        VStack {
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
                
                VStack(spacing: 26) {
                    header
                    
                    tabSelector
                    contentView
                    addButton
                    Spacer(minLength: 12)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .sheet(isPresented: $showAddSheet) {
                AddItemSheet(
                    assignments: $assignments,
                    tests: $tests,
                    classes: $classes,
                    defaultTab: selectedTab,
                    editingAssignment: nil,
                    editingTest: nil,
                    themeColor: themeColor
                )
            }
            .sheet(item: $editingAssignment) { assignment in
                AddItemSheet(
                    assignments: $assignments,
                    tests: $tests,
                    classes: $classes,
                    defaultTab: .assignments,
                    editingAssignment: assignment,
                    editingTest: nil,
                    themeColor: themeColor
                )
            }
            .sheet(item: $editingTest) { test in
                AddItemSheet(
                    assignments: $assignments,
                    tests: $tests,
                    classes: $classes,
                    defaultTab: .tests,
                    editingAssignment: nil,
                    editingTest: test,
                    themeColor: themeColor
                )
            }
            .sheet(isPresented: $showClassManager) {
                ClassManagerSheet(classes: $classes, themeColor: themeColor)
            }
            .onAppear {
                withAnimation {
                    animateContent = true
                }
            }
            
            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(themeColor)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.black)
        
        }
        .toolbar { progressToolbar(currentStep: 6) {
            onContinue()
        } }
        .background(Color.black)
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            Text("Track your upcoming work")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            Text("Add assignments and tests to stay organized.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.top, 12)
        .opacity(animateContent ? 1.0 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.easeOut(duration: 0.8), value: animateContent)
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            ZStack {
                                if selectedTab == tab {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(themeColor)
                                        .matchedGeometryEffect(id: "tab", in: tabNamespace)
                                }
                            }
                        )
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
        .opacity(animateContent ? 1.0 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.easeOut(duration: 0.8), value: animateContent)
    }
    
    private var contentView: some View {
        Group {
            if (selectedTab == .assignments && assignments.isEmpty) || (selectedTab == .tests && tests.isEmpty) {
                VStack(spacing: 16) {
                    Image(systemName: selectedTab == .assignments ? "doc.text" : "graduationcap")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.6))
                    Text("No \(selectedTab.rawValue.lowercased()) yet")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    Text("Add your first \(selectedTab == .assignments ? "assignment" : "test") below")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.13, green: 0.13, blue: 0.15))
                        .shadow(color: .black.opacity(0.6), radius: 6, y: 3)
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if selectedTab == .assignments {
                            ForEach(assignments) { assignment in
                                AssignmentCard(assignment: assignment) {
                                    editingAssignment = assignment
                                } onDelete: {
                                    deleteAssignment(assignment)
                                }
                            }
                        } else {
                            ForEach(tests) { test in
                                TestCard(test: test) {
                                    editingTest = test
                                } onDelete: {
                                    deleteTest(test)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: 320)
            }
        }
        .scaleEffect(animateContent ? 1.0 : 0.8)
        .opacity(animateContent ? 1.0 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
    }
    
    private var addButton: some View {
        Button {
            showAddSheet = true
        } label: {
            Label("Add \(selectedTab == .assignments ? "assignment" : "test")", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.clear)
                .foregroundColor(themeColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(themeColor, lineWidth: 2)
                )
                .cornerRadius(14)
        }
        .scaleEffect(animateContent ? 1.0 : 0.8)
        .opacity(animateContent ? 1.0 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
    }
    
    private func deleteAssignment(_ assignment: Assignment) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            assignments.removeAll { $0.id == assignment.id }
        }
    }
    
    private func deleteTest(_ test: Test) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            tests.removeAll { $0.id == test.id }
        }
    }
    
    @Namespace private var tabNamespace
}

// MARK: - Class Manager Sheet
private struct ClassManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var classes: [String]
    let themeColor: Color
    
    @State private var newClass = ""
    @State private var editingIndex: Int? = nil
    @State private var editingText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Manage Your Classes")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text("Add, edit, or remove your classes to better organize your work")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    // Add new class
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(themeColor)
                            
                            TextField("Enter class name", text: $newClass)
                                .font(.body)
                                .foregroundColor(.white)
                                .textFieldStyle(PlainTextFieldStyle())
                            
                            Button("Add") {
                                addNewClass()
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(themeColor)
                            )
                            .disabled(newClass.trimmingCharacters(in: .whitespaces).isEmpty)
                            .opacity(newClass.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1.0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    
                    // Classes list
                    if classes.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "building.2")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.4))
                            
                            Text("No classes added yet")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Add your first class above")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(classes.enumerated()), id: \.offset) { index, className in
                                    ClassRow(
                                        className: className,
                                        index: index,
                                        isEditing: editingIndex == index,
                                        editingText: $editingText,
                                        themeColor: themeColor,
                                        onEdit: {
                                            startEditing(index: index, className: className)
                                        },
                                        onSave: {
                                            saveEdit(index: index)
                                        },
                                        onCancel: {
                                            cancelEdit()
                                        },
                                        onDelete: {
                                            deleteClass(at: index)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    
                    Spacer()
                    
                    // Done button
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(themeColor)
                            )
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
        }
    }
    
    private func addNewClass() {
        let trimmedClass = newClass.trimmingCharacters(in: .whitespaces)
        if !trimmedClass.isEmpty && !classes.contains(trimmedClass) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                classes.append(trimmedClass)
            }
            newClass = ""
        }
    }
    
    private func startEditing(index: Int, className: String) {
        editingIndex = index
        editingText = className
    }
    
    private func saveEdit(index: Int) {
        let trimmedText = editingText.trimmingCharacters(in: .whitespaces)
        if !trimmedText.isEmpty && !classes.contains(trimmedText) {
            classes[index] = trimmedText
        }
        cancelEdit()
    }
    
    private func cancelEdit() {
        editingIndex = nil
        editingText = ""
    }
    
    private func deleteClass(at index: Int) {
        classes.remove(at: index)
    }
}

// MARK: - Class Row
private struct ClassRow: View {
    let className: String
    let index: Int
    let isEditing: Bool
    @Binding var editingText: String
    let themeColor: Color
    
    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20)
            
            if isEditing {
                TextField("Class name", text: $editingText)
                    .font(.body)
                    .foregroundColor(.white)
                    .textFieldStyle(PlainTextFieldStyle())
                
                Button("Save") {
                    onSave()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(themeColor)
                )
                
                Button("Cancel") {
                    onCancel()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            } else {
                Text(className)
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .alert("Delete Class", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(className)'?")
        }
    }
}

// MARK: - Unified Add/Edit Item Sheet
private struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ContentModel.self) var contentModel
    
    @Binding var assignments: [Assignment]
    @Binding var tests: [Test]
    @Binding var classes: [String]
    
    @State private var selectedTab: UpcomingWorkView.Tab
    @State private var title = ""
    @State private var classTitle = ""
    @State private var showingClassManager = false
    @State private var dueDate = Date()
    @State private var dueTime = Date()
    @State private var priority = 3
    @State private var estimatedMinutes = 60
    @State private var preferences = ""
    @State private var prepared = false
    @State private var showAdvanced = false
    
    let editingAssignment: Assignment?
    let editingTest: Test?
    let themeColor: Color
    
    private var isEditing: Bool {
        editingAssignment != nil || editingTest != nil
    }
    
    init(assignments: Binding<[Assignment]>, tests: Binding<[Test]>, classes: Binding<[String]>, defaultTab: UpcomingWorkView.Tab, editingAssignment: Assignment?, editingTest: Test?, themeColor: Color) {
        _assignments = assignments
        _tests = tests
        _classes = classes
        _selectedTab = State(initialValue: defaultTab)
        self.editingAssignment = editingAssignment
        self.editingTest = editingTest
        self.themeColor = themeColor
        
        // Initialize with editing values if editing
        if let assignment = editingAssignment {
            _title = State(initialValue: assignment.assignmentTitle)
            _classTitle = State(initialValue: assignment.classTitle)
            _dueDate = State(initialValue: assignment.dueDate)
            _dueTime = State(initialValue: assignment.dueDate)
            _estimatedMinutes = State(initialValue: assignment.estimatedMinutesLeftToComplete)
            _preferences = State(initialValue: assignment.extraPreferenceInfo)
            _showAdvanced = State(initialValue: !assignment.extraPreferenceInfo.isEmpty)
        } else if let test = editingTest {
            _title = State(initialValue: test.testTitle)
            _classTitle = State(initialValue: test.classTitle)
            _dueDate = State(initialValue: test.date)
            _dueTime = State(initialValue: test.date)
            _estimatedMinutes = State(initialValue: test.studyMinutesLeft)
            _preferences = State(initialValue: test.extraPreferenceInfo)
            _prepared = State(initialValue: test.prepared)
            _showAdvanced = State(initialValue: !test.extraPreferenceInfo.isEmpty)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            mainContent
                                .padding(.horizontal, 24)
                                .padding(.top, 24)
                            
                            // Advanced options toggle
                            VStack(spacing: 16) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showAdvanced.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Text("Work preferences")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.white.opacity(0.8))
                                        
                                        Spacer()
                                        
                                        Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.6))
                                            .rotationEffect(.degrees(showAdvanced ? 180 : 0))
                                    }
                                    .padding(.horizontal, 24)
                                }
                                
                                if showAdvanced {
                                    VStack(spacing: 12) {
                                        CompactTextEditor(
                                            text: $preferences,
                                            placeholder: selectedTab == .assignments ? 
                                                "When do you prefer to work on this? (optional)" : 
                                                "When do you prefer to study? (optional)"
                                        )
                                    }
                                    .padding(.horizontal, 24)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            
                            Spacer(minLength: 80)
                        }
                        .padding(.bottom, 20)
                    }
                    
                    // Save button
                    saveButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                        .background(Color.black)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingClassManager) {
                ClassManagerSheet(classes: $classes, themeColor: themeColor)
            }
            .onAppear {
                setupDefaults()
            }
        }
    }
    
    private func setupDefaults() {
        // Only set defaults if not editing
        if !isEditing {
            let calendar = Calendar.current
            let today = Date()
            
            if let defaultDue = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: today) {
                dueDate = defaultDue
                dueTime = defaultDue
            }
            
            estimatedMinutes = selectedTab == .assignments ? 60 : 120
        }
    }
    
    private var headerSection: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(headerTitle)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .opacity(0)
            .disabled(true)
        }
    }
    
    private var headerTitle: String {
        if isEditing {
            return selectedTab == .assignments ? "Edit Assignment" : "Edit Test"
        } else {
            return selectedTab == .assignments ? "New Assignment" : "New Test"
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 20) {
            // Title input
            CleanTextField(
                text: $title,
                placeholder: selectedTab == .assignments ? "Assignment title" : "Test title",
                icon: selectedTab == .assignments ? "doc.text" : "graduationcap"
            )
            
            // Class and manage button
            HStack(spacing: 12) {
                if !classes.isEmpty {
                    Menu {
                        Button("None") {
                            classTitle = ""
                        }
                        
                        Divider()
                        
                        ForEach(classes, id: \.self) { className in
                            Button(className) {
                                classTitle = className
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "building.2")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20)
                            
                            Text(classTitle.isEmpty ? "Select class" : classTitle)
                                .font(.body)
                                .foregroundColor(classTitle.isEmpty ? .white.opacity(0.4) : .white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                } else {
                    CleanTextField(
                        text: $classTitle,
                        placeholder: "Class name",
                        icon: "building.2"
                    )
                }
                
                Button {
                    showingClassManager = true
                } label: {
                    Image(systemName: classes.isEmpty ? "plus.circle" : "gear")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeColor)
                        .frame(width: 44, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
            }
            
            // Date and time in one row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Date")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .labelsHidden()
                        .colorScheme(.dark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Time")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    DatePicker("", selection: $dueTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(CompactDatePickerStyle())
                        .labelsHidden()
                        .colorScheme(.dark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            
            // Priority (assignments only) and time in one row
            HStack(spacing: 12) {
                if selectedTab == .assignments {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Priority")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack(spacing: 8) {
                            CompactPriorityButton(title: "Low", priority: 1, selectedPriority: $priority, color: .green)
                            CompactPriorityButton(title: "Med", priority: 3, selectedPriority: $priority, color: .orange)
                            CompactPriorityButton(title: "High", priority: 5, selectedPriority: $priority, color: .red)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedTab == .assignments ? "Est. Time" : "Study Time")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    HStack(spacing: 8) {
                        Button("-") {
                            if estimatedMinutes > 15 {
                                estimatedMinutes = max(15, estimatedMinutes - 15)
                            }
                        }
                        .foregroundColor(themeColor)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                        
                        Text("\(estimatedMinutes)m")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .frame(minWidth: 40)
                        
                        Button("+") {
                            if estimatedMinutes < 480 {
                                estimatedMinutes = min(480, estimatedMinutes + 15)
                            }
                        }
                        .foregroundColor(themeColor)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            
            // Test preparation toggle (only when editing tests)
            if selectedTab == .tests && isEditing {
                HStack {
                    Text("Ready for test")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    Toggle("", isOn: $prepared)
                        .toggleStyle(SwitchToggleStyle(tint: themeColor))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var saveButton: some View {
        Button(action: saveItem) {
            Text(saveButtonTitle)
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(themeColor)
                        .shadow(color: themeColor.opacity(0.3), radius: 4, y: 2)
                )
        }
        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1.0)
    }
    
    private var saveButtonTitle: String {
        if isEditing {
            return "Save Changes"
        } else {
            return selectedTab == .assignments ? "Add Assignment" : "Add Test"
        }
    }
    
    private func combineDateTime() -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: dueTime),
            minute: calendar.component(.minute, from: dueTime),
            second: 0,
            of: dueDate
        ) ?? dueDate
    }
    
    private func saveItem() {
        let combinedDate = combineDateTime()
        
        if selectedTab == .assignments {
            if let editingAssignment = editingAssignment {
                // Update existing assignment
                if let index = assignments.firstIndex(where: { $0.id == editingAssignment.id }) {
                    assignments[index] = Assignment(
                        id: editingAssignment.id,
                        assignmentTitle: title.trimmingCharacters(in: .whitespaces),
                        classTitle: classTitle,
                        dueDate: combinedDate,
                        extraPreferenceInfo: preferences,
                        estimatedMinutesLeftToComplete: estimatedMinutes,
                        completed: editingAssignment.completed
                    )
                }
            } else {
                // Add new assignment
                let assignment = Assignment(
                    assignmentTitle: title.trimmingCharacters(in: .whitespaces),
                    classTitle: classTitle,
                    dueDate: combinedDate,
                    extraPreferenceInfo: preferences,
                    estimatedMinutesLeftToComplete: estimatedMinutes,
                    completed: false
                )
                assignments.append(assignment)
            }
        } else {
            if let editingTest = editingTest {
                // Update existing test
                if let index = tests.firstIndex(where: { $0.id == editingTest.id }) {
                    tests[index] = Test(
                        id: editingTest.id,
                        testTitle: title.trimmingCharacters(in: .whitespaces),
                        classTitle: classTitle,
                        date: combinedDate,
                        extraPreferenceInfo: preferences,
                        studyMinutesLeft: estimatedMinutes,
                        prepared: prepared
                    )
                }
            } else {
                // Add new test
                let test = Test(
                    testTitle: title.trimmingCharacters(in: .whitespaces),
                    classTitle: classTitle,
                    date: combinedDate,
                    extraPreferenceInfo: preferences,
                    studyMinutesLeft: estimatedMinutes,
                    prepared: false
                )
                tests.append(test)
            }
        }
        
        dismiss()
    }
}

// MARK: - Helper Components
private struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

private struct CleanTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .font(.body)
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

private struct CompactTextEditor: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .frame(height: 80)
            
            if text.isEmpty {
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
            
            TextEditor(text: $text)
                .font(.subheadline)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
    }
}

private struct CompactPriorityButton: View {
    let title: String
    let priority: Int
    @Binding var selectedPriority: Int
    let color: Color
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPriority = priority
            }
        }) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(selectedPriority == priority ? .white : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedPriority == priority ? color : Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedPriority == priority ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
        }
    }
}

private struct ProfessionalTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .font(.body)
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

private struct ProfessionalTextEditor: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .frame(height: 120)
            
            if text.isEmpty {
                Text(placeholder)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
            
            TextEditor(text: $text)
                .font(.body)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
    }
}

private struct PriorityButton: View {
    let title: String
    let priority: Int
    @Binding var selectedPriority: Int
    let color: Color
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPriority = priority
            }
        }) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(selectedPriority == priority ? .white : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedPriority == priority ? color : Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedPriority == priority ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Assignment Card
private struct AssignmentCard: View {
    let assignment: Assignment
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    
    private var timeUntilDue: String {
        let components = Calendar.current.dateComponents([.day, .hour], from: Date(), to: assignment.dueDate)
        let days = components.day ?? 0
        let hours = components.hour ?? 0
        
        if days > 0 {
            return days == 1 ? "Tomorrow, \(assignment.dueDate.formatted(date: .omitted, time: .shortened))" : "\(assignment.dueDate.formatted(date: .abbreviated, time: .shortened))"
        } else if hours > 0 {
            return "Today, \(assignment.dueDate.formatted(date: .omitted, time: .shortened))"
        } else {
            return "Due now"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assignment.assignmentTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        if !assignment.classTitle.isEmpty {
                            Text(assignment.classTitle)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        // Menu button for delete
                        Button(action: { showDeleteAlert = true }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(timeUntilDue)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isDeleting ? 0.95 : 1.0)
        .opacity(isDeleting ? 0.7 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDeleting)
        .alert("Delete Assignment", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                isDeleting = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onDelete()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(assignment.assignmentTitle)'?")
        }
    }
}

// MARK: - Test Card
private struct TestCard: View {
    let test: Test
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    
    private var timeUntilTest: String {
        let components = Calendar.current.dateComponents([.day, .hour], from: Date(), to: test.date)
        let days = components.day ?? 0
        let hours = components.hour ?? 0
        
        if days > 0 {
            return days == 1 ? "Tomorrow, \(test.date.formatted(date: .omitted, time: .shortened))" : "\(test.date.formatted(date: .abbreviated, time: .shortened))"
        } else if hours > 0 {
            return "Today, \(test.date.formatted(date: .omitted, time: .shortened))"
        } else {
            return "Now"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(test.testTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        if !test.classTitle.isEmpty {
                            Text(test.classTitle)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text(test.prepared ? "Ready" : "Preparing")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(test.prepared ? .green : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill((test.prepared ? Color.green : Color.orange).opacity(0.2))
                            )
                        
                        // Menu button for delete
                        Button(action: { showDeleteAlert = true }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(timeUntilTest)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isDeleting ? 0.95 : 1.0)
        .opacity(isDeleting ? 0.7 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDeleting)
        .alert("Delete Test", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                isDeleting = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onDelete()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(test.testTitle)'?")
        }
    }
}