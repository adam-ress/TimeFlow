//
//  AssignmentsView.swift
//  TimeFlow
//
//  Created by Adam Ress on 7/25/25.
//

import SwiftUI

struct AssignmentsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ContentModel.self) var contentModel
    
    @Binding var selectedTabPage: Int
    
    @State private var selectedTab: AssignmentTab = .assignments
    @State private var showingAssignmentEditor = false
    @State private var showingTestEditor = false
    @State private var selectedAssignment: Assignment?
    @State private var selectedTest: Test?
    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: DeleteableItem?
    @State private var showingCloseButton = false
    @State private var filterCompleted: CompletionFilter = .all
    @State private var sortOption: SortOption = .dueDate
    @State private var animateContent = false
    
    // Animation namespace
    @Namespace private var tabAnimation
    
    enum AssignmentTab: String, CaseIterable {
        case assignments = "Assignments"
        case tests = "Tests"
        
        var icon: String {
            switch self {
            case .assignments: return "doc.text.fill"
            case .tests: return "graduationcap.fill"
            }
        }
    }
    
    enum CompletionFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case completed = "Completed"
    }
    
    enum SortOption: String, CaseIterable {
        case dueDate = "Due Date"
        case alphabetical = "Alphabetical"
        case timeLeft = "Time Left"
        
        var icon: String {
            switch self {
            case .dueDate: return "calendar"
            case .alphabetical: return "textformat.abc"
            case .timeLeft: return "clock"
            }
        }
    }
    
    enum DeleteableItem {
        case assignment(Assignment)
        case test(Test)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
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
                
                VStack(spacing: 0) {
                    headerView
                    
                    if (selectedTab == .assignments ? filteredAssignments.isEmpty : filteredTests.isEmpty) &&
                       (contentModel.user?.assignments.isEmpty == true && contentModel.user?.tests.isEmpty == true) {
                        emptyStateView
                    } else {
                        contentView
                    }
                    
                    Spacer()
                    
                    TabBarView(selectedTab: $selectedTabPage)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAssignmentEditor) {
            AssignmentEditorView(
                assignment: selectedAssignment ?? createNewAssignment(),
                onSave: { assignment in
                    saveAssignment(assignment)
                },
                onDelete: selectedAssignment != nil ? { assignment in
                    deleteAssignment(assignment)
                } : nil
            )
        }
        .sheet(isPresented: $showingTestEditor) {
            TestEditorView(
                test: selectedTest ?? createNewTest(),
                onSave: { test in
                    saveTest(test)
                },
                onDelete: selectedTest != nil ? { test in
                    deleteTest(test)
                } : nil
            )
        }
        .alert("Delete Item", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    switch item {
                    case .assignment(let assignment):
                        deleteAssignment(assignment)
                    case .test(let test):
                        deleteTest(test)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this item? This action cannot be undone.")
        }
        .onAppear {
            loadData()
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedTab.rawValue)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(statusText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Tab switcher button
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedTab = selectedTab == .assignments ? .tests : .assignments
                        }
                    } label: {
                        Image(systemName: selectedTab == .assignments ? "graduationcap.fill" : "doc.text.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(AppTheme.Colors.background.opacity(0.5))
                            )
                    }
                    
                    // Add button
                    Button {
                        if selectedTab == .assignments {
                            selectedAssignment = nil
                            showingAssignmentEditor = true
                        } else {
                            selectedTest = nil
                            showingTestEditor = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(AppTheme.Colors.accent)
                                    .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 4, y: 2)
                            )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            // Subtle divider
            Rectangle()
                .fill(AppTheme.Colors.overlay.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 24)
        }
        .background(AppTheme.Colors.background)
        .opacity(animateContent ? 1.0 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.easeOut(duration: 0.6).delay(0.1), value: animateContent)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.accent.opacity(0.1),
                                AppTheme.Colors.accent.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: selectedTab.icon)
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(AppTheme.Colors.accent)
                    )
                
                VStack(spacing: 12) {
                    Text("No \(selectedTab.rawValue)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Start by adding your \(selectedTab.rawValue.lowercased()) to keep track of deadlines and study time")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 32)
                }
                
                Button {
                    if selectedTab == .assignments {
                        selectedAssignment = nil
                        showingAssignmentEditor = true
                    } else {
                        selectedTest = nil
                        showingTestEditor = true
                    }
                } label: {
                    Text("Add \(selectedTab.rawValue.dropLast())")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.accent, AppTheme.Colors.accent.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 8, y: 4)
                        )
                }
                .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .opacity(animateContent ? 1.0 : 0)
        .scaleEffect(animateContent ? 1.0 : 0.9)
        .animation(.easeOut(duration: 0.8).delay(0.2), value: animateContent)
    }
    
    // MARK: - Content View
    private var contentView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                if selectedTab == .assignments {
                    ForEach(filteredAssignments, id: \.id) { assignment in
                        assignmentRow(assignment)
                    }
                } else {
                    ForEach(filteredTests, id: \.id) { test in
                        testRow(test)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Assignment Row
    private func assignmentRow(_ assignment: Assignment) -> some View {
        HStack(spacing: 16) {
            
            // Main column
            VStack(alignment: .leading, spacing: 6) {
                
                HStack(spacing: 8) {
                // Title
                Text(assignment.assignmentTitle)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .strikethrough(assignment.completed)
                    .opacity(assignment.completed ? 0.6 : 1)
            
                    if !assignment.classTitle.isEmpty {
                        Text(assignment.classTitle)
                            .font(.caption.weight(.medium))
                            .foregroundColor(subjectColor(for: assignment.classTitle))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(subjectColor(for: assignment.classTitle).opacity(0.15))
                            )
                    }
                    Spacer()
                }
                
                // Time + due date
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("\(assignment.estimatedMinutesLeftToComplete)m • \(formatDueDate(assignment.dueDate))")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Options menu (three‑dot)
            Menu {
                Button {
                    toggleAssignmentCompletion(assignment)
                } label: {
                    Label(assignment.completed ? "Mark Incomplete" : "Mark Complete",
                          systemImage: assignment.completed ? "xmark.circle" : "checkmark.circle")
                }
                
                Divider()
                
                Button {
                    selectedAssignment = assignment
                    showingAssignmentEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    itemToDelete = .assignment(assignment)
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: assignment.completed)
    }

    
    // MARK: - Test Row  
    private func testRow(_ test: Test) -> some View {
        HStack(spacing: 16) {
            
            // Main column
            VStack(alignment: .leading, spacing: 6) {
                
                HStack(spacing: 8) {
                    // Title
                    Text(test.testTitle)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .strikethrough(test.prepared)
                        .opacity(test.prepared ? 0.6 : 1)
                    
                    if !test.classTitle.isEmpty {
                        Text(test.classTitle)
                            .font(.caption.weight(.medium))
                            .foregroundColor(subjectColor(for: test.classTitle))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(subjectColor(for: test.classTitle).opacity(0.15))
                            )
                    }
                    Spacer()
                }
                
                // Study time + test date
                HStack(spacing: 8) {
                    Image(systemName: "book")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("\(test.studyMinutesLeft)m • \(formatTestDate(test.date))")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Options menu (three‑dot)
            Menu {
                Button {
                    toggleTestPreparation(test)
                } label: {
                    Label(test.prepared ? "Mark Unprepared" : "Mark Prepared",
                          systemImage: test.prepared ? "xmark.circle" : "checkmark.circle")
                }
                
                Divider()
                
                Button {
                    selectedTest = test
                    showingTestEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    itemToDelete = .test(test)
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: test.prepared)
    }

    
    // MARK: - Helper Functions for Enhanced Cards
    private func subjectIcon(for className: String) -> String {
        let lowercased = className.lowercased()
        if lowercased.contains("science") || lowercased.contains("chemistry") || lowercased.contains("physics") {
            return "atom"
        } else if lowercased.contains("english") || lowercased.contains("literature") || lowercased.contains("writing") {
            return "book"
        } else if lowercased.contains("history") || lowercased.contains("social") {
            return "globe"
        } else if lowercased.contains("art") || lowercased.contains("design") {
            return "paintbrush"
        } else if lowercased.contains("music") {
            return "music.note"
        } else if lowercased.contains("computer") || lowercased.contains("programming") || lowercased.contains("coding") {
            return "laptopcomputer"
        } else {
            return "book.fill"
        }
    }
    
    private func subjectColor(for className: String) -> Color {
        let lowercased = className.lowercased()
        if lowercased.contains("science") || lowercased.contains("chemistry") || lowercased.contains("physics") {
            return .green
        } else if lowercased.contains("english") || lowercased.contains("literature") || lowercased.contains("writing") {
            return .orange
        } else if lowercased.contains("history") || lowercased.contains("social") {
            return .brown
        } else if lowercased.contains("art") || lowercased.contains("design") {
            return .purple
        } else if lowercased.contains("music") {
            return .pink
        } else if lowercased.contains("computer") || lowercased.contains("programming") || lowercased.contains("coding") {
            return .cyan
        } else {
            return AppTheme.Colors.accent
        }
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let now = Date()
        let timeInterval = date.timeIntervalSince(now)
        let daysUntilDue = Int(timeInterval / (24 * 60 * 60))
        
        let dateString = date.formatted(date: .abbreviated, time: .omitted)
        
        if timeInterval < 0 {
            let daysOverdue = abs(daysUntilDue)
            return daysOverdue == 0 ? "Overdue" : "\(dateString) (\(daysOverdue)d overdue)"
        } else if daysUntilDue == 0 {
            return "Today"
        } else if daysUntilDue == 1 {
            return "Tomorrow"
        } else {
            return "\(dateString) (\(daysUntilDue)d)"
        }
    }
    
    private func formatTestDate(_ date: Date) -> String {
        let now = Date()
        let timeInterval = date.timeIntervalSince(now)
        let daysUntilTest = Int(timeInterval / (24 * 60 * 60))
        
        let dateString = date.formatted(date: .abbreviated, time: .omitted)
        
        if timeInterval < 0 {
            return "\(dateString) (past)"
        } else if daysUntilTest == 0 {
            return "Today"
        } else if daysUntilTest == 1 {
            return "Tomorrow"
        } else {
            return "\(dateString) (\(daysUntilTest)d)"
        }
    }
    
    private func dueDateUrgencyColor(_ date: Date) -> Color {
        let now = Date()
        let timeInterval = date.timeIntervalSince(now)
        let daysUntilDue = timeInterval / (24 * 60 * 60)
        
        if daysUntilDue < 0 {
            return .red // Overdue
        } else if daysUntilDue < 3 {
            return .red // < 3 days
        } else if daysUntilDue < 7 {
            return .orange // 3-7 days
        } else {
            return .green // > 7 days
        }
    }
    
    // MARK: - Computed Properties
    private var statusText: String {
        if selectedTab == .assignments {
            let total = contentModel.user?.assignments.count ?? 0
            let completed = contentModel.user?.assignments.filter { $0.completed }.count ?? 0
            return "\(completed)/\(total) completed"
        } else {
            let total = contentModel.user?.tests.count ?? 0
            let prepared = contentModel.user?.tests.filter { $0.prepared }.count ?? 0
            return "\(prepared)/\(total) prepared"
        }
    }
    
    private var filteredAssignments: [Assignment] {
        var assignments = contentModel.user?.assignments ?? []
        
        // Apply completion filter
        switch filterCompleted {
        case .all:
            break
        case .pending:
            assignments = assignments.filter { !$0.completed }
        case .completed:
            assignments = assignments.filter { $0.completed }
        }
        
        // Apply sorting
        switch sortOption {
        case .dueDate:
            assignments.sort { $0.dueDate < $1.dueDate }
        case .alphabetical:
            assignments.sort { $0.assignmentTitle < $1.assignmentTitle }
        case .timeLeft:
            assignments.sort { $0.estimatedMinutesLeftToComplete < $1.estimatedMinutesLeftToComplete }
        }
        
        return assignments
    }
    
    private var filteredTests: [Test] {
        var tests = contentModel.user?.tests ?? []
        
        // Apply completion filter
        switch filterCompleted {
        case .all:
            break
        case .pending:
            tests = tests.filter { !$0.prepared }
        case .completed:
            tests = tests.filter { $0.prepared }
        }
        
        // Apply sorting
        switch sortOption {
        case .dueDate:
            tests.sort { $0.date < $1.date }
        case .alphabetical:
            tests.sort { $0.testTitle < $1.testTitle }
        case .timeLeft:
            tests.sort { $0.studyMinutesLeft < $1.studyMinutesLeft }
        }
        
        return tests
    }
    
    // MARK: - Helper Functions
    private func loadData() {
        // Data is loaded from contentModel automatically
    }
    
    private func saveData() {
        Task {
            do {
                try await contentModel.saveUserInfo()
            } catch {
                print("❌ Failed to save assignments/tests: \(error)")
            }
        }
    }
    
    private func saveAssignment(_ assignment: Assignment) {
        if let index = contentModel.user?.assignments.firstIndex(where: { $0.id == assignment.id }) {
            contentModel.user?.assignments[index] = assignment
        } else {
            contentModel.user?.assignments.append(assignment)
        }
        saveData()
    }
    
    private func saveTest(_ test: Test) {
        if let index = contentModel.user?.tests.firstIndex(where: { $0.id == test.id }) {
            contentModel.user?.tests[index] = test
        } else {
            contentModel.user?.tests.append(test)
        }
        saveData()
    }
    
    private func deleteAssignment(_ assignment: Assignment) {
        contentModel.user?.assignments.removeAll { $0.id == assignment.id }
        saveData()
    }
    
    private func deleteTest(_ test: Test) {
        contentModel.user?.tests.removeAll { $0.id == test.id }
        saveData()
    }
    
    private func toggleAssignmentCompletion(_ assignment: Assignment) {
        if let index = contentModel.user?.assignments.firstIndex(where: { $0.id == assignment.id }) {
            contentModel.user?.assignments[index].completed.toggle()
            saveData()
        }
    }
    
    private func toggleTestPreparation(_ test: Test) {
        if let index = contentModel.user?.tests.firstIndex(where: { $0.id == test.id }) {
            contentModel.user?.tests[index].prepared.toggle()
            saveData()
        }
    }
    
    private func createNewAssignment() -> Assignment {
        Assignment(
            assignmentTitle: "",
            classTitle: "",
            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        )
    }
    
    private func createNewTest() -> Test {
        Test(
            testTitle: "",
            classTitle: "",
            date: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        )
    }
}

// MARK: - Assignment Editor View
struct AssignmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ContentModel.self) var contentModel
    
    @State private var assignment: Assignment
    @State private var dueDate: Date
    @State private var showingClassManager = false
    
    let onSave: (Assignment) -> Void
    let onDelete: ((Assignment) -> Void)?
    
    private let isNewAssignment: Bool
    
    init(assignment: Assignment, onSave: @escaping (Assignment) -> Void, onDelete: ((Assignment) -> Void)? = nil) {
        self._assignment = State(initialValue: assignment)
        self._dueDate = State(initialValue: assignment.dueDate)
        self.onSave = onSave
        self.onDelete = onDelete
        self.isNewAssignment = assignment.assignmentTitle.isEmpty
    }
    
    var userClasses: [String] {
        contentModel.user?.classes ?? []
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text(isNewAssignment ? "New Assignment" : "Edit Assignment")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Spacer()
                        
                        Button("Save") {
                            saveAssignment()
                        }
                        .foregroundColor(AppTheme.Colors.accent)
                        .fontWeight(.semibold)
                        .disabled(assignment.assignmentTitle.isEmpty || assignment.classTitle.isEmpty)
                        .opacity(assignment.assignmentTitle.isEmpty || assignment.classTitle.isEmpty ? 0.6 : 1.0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Assignment title
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Assignment Title")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                TextField("Enter assignment title", text: $assignment.assignmentTitle)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(AppTheme.Colors.cardBackground)
                                            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                                    )
                            }
                            
                            // Class selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Class")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                HStack(spacing: 12) {
                                    if !userClasses.isEmpty {
                                        Menu {
                                            Button("None") {
                                                assignment.classTitle = ""
                                            }
                                            
                                            Divider()
                                            
                                            ForEach(userClasses, id: \.self) { className in
                                                Button(className) {
                                                    assignment.classTitle = className
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: "building.2")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                                    .frame(width: 20)
                                                
                                                Text(assignment.classTitle.isEmpty ? "Select class" : assignment.classTitle)
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(assignment.classTitle.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(AppTheme.Colors.cardBackground)
                                                    .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                                            )
                                        }
                                    } else {
                                        TextField("Enter class name", text: $assignment.classTitle)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(AppTheme.Colors.cardBackground)
                                                    .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                                            )
                                    }
                                    
                                    Button {
                                        showingClassManager = true
                                    } label: {
                                        Image(systemName: userClasses.isEmpty ? "plus.circle" : "gear")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(AppTheme.Colors.accent)
                                            .frame(width: 44, height: 48)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(AppTheme.Colors.cardBackground)
                                                    .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                                            )
                                    }
                                }
                            }
                            
                            // Due date
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Due Date")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(GraphicalDatePickerStyle())
                                    .frame(maxHeight: 400)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(AppTheme.Colors.cardBackground)
                                            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                                    )
                            }
                            
                            // Time estimation
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Estimated Time Needed")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                HStack {
                                    Button("-") {
                                        if assignment.estimatedMinutesLeftToComplete > 15 {
                                            assignment.estimatedMinutesLeftToComplete = max(15, assignment.estimatedMinutesLeftToComplete - 15)
                                        }
                                    }
                                    .foregroundColor(AppTheme.Colors.accent)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(AppTheme.Colors.accent.opacity(0.1)))
                                    
                                    Spacer()
                                    
                                    VStack(spacing: 2) {
                                        Text("\(assignment.estimatedMinutesLeftToComplete)")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                        Text("minutes")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("+") {
                                        if assignment.estimatedMinutesLeftToComplete < 480 {
                                            assignment.estimatedMinutesLeftToComplete = min(480, assignment.estimatedMinutesLeftToComplete + 15)
                                        }
                                    }
                                    .foregroundColor(AppTheme.Colors.accent)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(AppTheme.Colors.accent.opacity(0.1)))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppTheme.Colors.cardBackground)
                                        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                                )
                            }
                            
                            // AI preferences
                            VStack(alignment: .leading, spacing: 8) {
                                Text("AI Scheduling Preferences (Optional)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                ZStack(alignment: .topLeading) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppTheme.Colors.cardBackground)
                                        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                                        .frame(height: 100)
                                    
                                    if assignment.extraPreferenceInfo.isEmpty {
                                        Text("Anything the AI should know about scheduling this assignment? (e.g., preferred times, energy levels needed, materials required)")
                                            .font(.system(size: 16))
                                            .foregroundColor(AppTheme.Colors.textTertiary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                    }
                                    
                                    TextEditor(text: $assignment.extraPreferenceInfo)
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                        .scrollContentBackground(.hidden)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                }
                            }
                            
                            if !isNewAssignment, let onDelete = onDelete {
                                Button("Delete Assignment") {
                                    onDelete(assignment)
                                    dismiss()
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingClassManager) {
                ClassManagerSheet(classes: Binding(
                    get: { contentModel.user?.classes ?? [] },
                    set: { newClasses in
                        contentModel.user?.classes = newClasses
                        Task {
                            try? await contentModel.saveUserInfo()
                        }
                    }
                ))
            }
        }
    }
    
    private func saveAssignment() {
        assignment.dueDate = dueDate
        onSave(assignment)
        dismiss()
    }
}

// MARK: - Test Editor View
struct TestEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ContentModel.self) var contentModel
    
    @State private var test: Test
    @State private var testDate: Date
    @State private var showingClassManager = false
    
    let onSave: (Test) -> Void
    let onDelete: ((Test) -> Void)?
    
    private let isNewTest: Bool
    
    init(test: Test, onSave: @escaping (Test) -> Void, onDelete: ((Test) -> Void)? = nil) {
        self._test = State(initialValue: test)
        self._testDate = State(initialValue: test.date)
        self.onSave = onSave
        self.onDelete = onDelete
        self.isNewTest = test.testTitle.isEmpty
    }
    
    var userClasses: [String] {
        contentModel.user?.classes ?? []
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text(isNewTest ? "New Test" : "Edit Test")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Spacer()
                        
                        Button("Save") {
                            saveTest()
                        }
                        .foregroundColor(AppTheme.Colors.accent)
                        .fontWeight(.semibold)
                        .disabled(test.testTitle.isEmpty || test.classTitle.isEmpty)
                        .opacity(test.testTitle.isEmpty || test.classTitle.isEmpty ? 0.6 : 1.0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Test title
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Test Title")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                TextField("Enter test title", text: $test.testTitle)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(AppTheme.Colors.cardBackground)
                                            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                                    )
                            }
                            
                            // Class selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Class")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                HStack(spacing: 12) {
                                    if !userClasses.isEmpty {
                                        Menu {
                                            Button("None") {
                                                test.classTitle = ""
                                            }
                                            
                                            Divider()
                                            
                                            ForEach(userClasses, id: \.self) { className in
                                                Button(className) {
                                                    test.classTitle = className
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: "building.2")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                                    .frame(width: 20)
                                                
                                                Text(test.classTitle.isEmpty ? "Select class" : test.classTitle)
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(test.classTitle.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(AppTheme.Colors.cardBackground)
                                                    .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                                            )
                                        }
                                    } else {
                                        TextField("Enter class name", text: $test.classTitle)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(AppTheme.Colors.cardBackground)
                                                    .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                                            )
                                    }
                                    
                                    Button {
                                        showingClassManager = true
                                    } label: {
                                        Image(systemName: userClasses.isEmpty ? "plus.circle" : "gear")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(AppTheme.Colors.accent)
                                            .frame(width: 44, height: 48)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(AppTheme.Colors.cardBackground)
                                                    .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                                            )
                                    }
                                }
                            }
                            
                            // Test date
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Test Date")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                DatePicker("Test Date", selection: $testDate, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(GraphicalDatePickerStyle())
                                    .frame(maxHeight: 400)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(AppTheme.Colors.cardBackground)
                                            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                                    )
                            }
                            
                            // Study time
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Study Time Left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                HStack {
                                    Button("-") {
                                        if test.studyMinutesLeft > 15 {
                                            test.studyMinutesLeft = max(15, test.studyMinutesLeft - 15)
                                        }
                                    }
                                    .foregroundColor(AppTheme.Colors.accent)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(AppTheme.Colors.accent.opacity(0.1)))
                                    
                                    Spacer()
                                    
                                    VStack(spacing: 2) {
                                        Text("\(test.studyMinutesLeft)")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                        Text("minutes")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("+") {
                                        if test.studyMinutesLeft < 480 {
                                            test.studyMinutesLeft = min(480, test.studyMinutesLeft + 15)
                                        }
                                    }
                                    .foregroundColor(AppTheme.Colors.accent)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(AppTheme.Colors.accent.opacity(0.1)))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppTheme.Colors.cardBackground)
                                        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                                )
                            }
                            
                            // Additional preferences
                            VStack(alignment: .leading, spacing: 8) {
                                Text("AI Scheduling Preferences (Optional)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                ZStack(alignment: .topLeading) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppTheme.Colors.cardBackground)
                                        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                                        .frame(height: 100)
                                    
                                    if test.extraPreferenceInfo.isEmpty {
                                        Text("Anything the AI should know about scheduling study time for this test? (e.g., preferred study times, difficulty level, review materials needed)")
                                            .font(.system(size: 16))
                                            .foregroundColor(AppTheme.Colors.textTertiary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                    }
                                    
                                    TextEditor(text: $test.extraPreferenceInfo)
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                        .scrollContentBackground(.hidden)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                }
                            }
                            
                            if !isNewTest, let onDelete = onDelete {
                                Button("Delete Test") {
                                    onDelete(test)
                                    dismiss()
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingClassManager) {
                ClassManagerSheet(classes: Binding(
                    get: { contentModel.user?.classes ?? [] },
                    set: { newClasses in
                        contentModel.user?.classes = newClasses
                        Task {
                            try? await contentModel.saveUserInfo()
                        }
                    }
                ))
            }
        }
    }
    
    private func saveTest() {
        test.date = testDate
        onSave(test)
        dismiss()
    }
}

// MARK: - Class Manager Sheet
private struct ClassManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var classes: [String]
    
    @State private var newClass = ""
    @State private var editingIndex: Int? = nil
    @State private var editingText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Manage Your Classes")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Add, edit, or remove your classes to better organize your work")
                            .font(.system(size: 16))
                            .multilineTextAlignment(.center)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(.top, 20)
                    
                    // Add new class
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.Colors.accent)
                            
                            TextField("Enter class name", text: $newClass)
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.textPrimary)
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
                                    .fill(AppTheme.Colors.accent)
                            )
                            .disabled(newClass.trimmingCharacters(in: .whitespaces).isEmpty)
                            .opacity(newClass.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1.0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.Colors.cardBackground)
                                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                        )
                    }
                    
                    // Classes list
                    if classes.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "building.2")
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text("No classes added yet")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Text("Add your first class above")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.textTertiary)
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
                                    .fill(AppTheme.Colors.accent)
                                    .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 4, y: 2)
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
    
    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(width: 20)
            
            if isEditing {
                TextField("Class name", text: $editingText)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textPrimary)
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
                        .fill(AppTheme.Colors.accent)
                )
                
                Button("Cancel") {
                    onCancel()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            } else {
                Text(className)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
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
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
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
