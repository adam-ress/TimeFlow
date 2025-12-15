//
//  HomeView.swift
//  TimeFlow
//
//  Created by Adam Ress on 7/21/25.
//

import SwiftUI

struct HomeView: View {
    @Environment(ContentModel.self) var contentModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: Int
    
    @State var events: [Event] = []
    @State private var userNote: String = ""
    @State private var showingNoteSheet = false
    @State private var showingSettings = false
    @State private var showingEditSchedule = false
    @State private var showCalendarView = false
    @State private var showAllUpcomingEvents = false
    @State private var showingFocusMode = false
    @State private var focusEvent: Event? = nil
    @State private var selectedPieSlice: PieChartSlice? = nil
    @Namespace private var eventCardAnimation
    
    private var theme: ThemeColorProvider {
        themeColors(colorScheme)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Subtle background gradient
                LinearGradient(
                    colors: [
                        theme.background,
                        AppTheme.Colors.secondary.opacity(0.3),
                        theme.background
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 0) {
                        // Header stays fully visible and functional
                        headerView
                        
                        // Content area with AI thinking overlay only here
                        ZStack {
                            Group {
                                if visibleEvents.isEmpty {
                                    emptyStateContentView
                                } else {
                                    if showCalendarView {
                                        calendarContentView
                                    } else {
                                        timelineScheduleContentView
                                    }
                                }
                            }
                            
                            // AI thinking overlay only over content area - now using ContentModel state
                            if contentModel.showingThinkingOverlay {
                                aiThinkingContentOverlay
                            }
                        }
                        
                        // Tab bar stays fully visible and functional at bottom
                        TabBarView(selectedTab: $selectedTab)
                    }
                )
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNoteSheet) {
                noteInputSheet
            }
            .sheet(isPresented: $showingSettings) {
                AccountView()
            }
            .sheet(isPresented: $showingEditSchedule) {
                EditScheduleView()
            }
            .onAppear {
                loadScheduleData()
                // Remove automatic background generation check
                // contentModel.checkForBackgroundGenerationOnStartup()
                
                if contentModel.loggedIn && contentModel.user == nil {
                    Task {
                        do {
                            try await contentModel.fetchUser()
                            await MainActor.run {
                                loadScheduleData()
                            }
                        } catch {
                            Logger.error("❌ Failed to fetch user on appear: \(error.localizedDescription)", category: .auth)
                        }
                    }
                } else if contentModel.loggedIn {
                    Task {
                        do {
                            try await contentModel.refreshUserData()
                            await MainActor.run {
                                loadScheduleData()
                            }
                            // Remove automatic schedule generation offer
                            // await contentModel.checkAndOfferScheduleGeneration()
                        } catch {
                            print("❌ Failed to refresh user data: \(error)")
                        }
                    }
                }
            }
            .onChange(of: contentModel.user?.currentSchedule) { oldSchedule, newSchedule in
                if let newSchedule = newSchedule {
                    events = newSchedule.isEmpty ? [] : newSchedule
                } else {
                    events = []
                }
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schedule")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    
                    Text(Date().formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if !visibleEvents.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showCalendarView.toggle()
                            }
                        } label: {
                            Image(systemName: showCalendarView ? "list.bullet" : "calendar")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(theme.cardBackground)
                                        .shadow(color: theme.cardShadow.opacity(0.1), radius: 2, y: 1)
                                )
                        }
                        
                        Button {
                            showingEditSchedule = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(theme.cardBackground)
                                        .shadow(color: theme.cardShadow.opacity(0.1), radius: 2, y: 1)
                                )
                        }
                    }
                    
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(theme.cardBackground)
                                    .shadow(color: theme.cardShadow.opacity(0.1), radius: 2, y: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            // Subtle divider
            Rectangle()
                .fill(theme.overlay.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 24)
        }
        .background(theme.background)
    }

    // MARK: - Content Views (separated from container logic)
    private var emptyStateContentView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 40) {
                Spacer(minLength: 60)
                
                VStack(spacing: 20) {
                    // More subtle icon presentation
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
                            Image(systemName: "calendar.day.timeline.leading")
                                .font(.system(size: 32, weight: .light))
                                .foregroundColor(AppTheme.Colors.accent)
                        )
                    
                    VStack(spacing: 12) {
                        Text("No schedule for today")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                        
                        Text("Create an AI-generated schedule based on your goals and commitments")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 16)
                    }
                }
                
                VStack(spacing: 16) {
                    if !userNote.isEmpty {
                        notePreviewCard
                    }
                    
                    actionButtonsRow
                }
                
                Spacer(minLength: 60)
            }
            .padding(.horizontal, 32)
            .opacity(contentModel.showingThinkingOverlay ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: contentModel.showingThinkingOverlay)
        }
    }

    private var notePreviewCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.Colors.accent.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "note.text")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.accent)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Context Note")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(userNote)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button("Edit") {
                showingNoteSheet = true
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(AppTheme.Colors.accent)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
                .shadow(color: theme.cardShadow.opacity(0.1), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.accent.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            Button {
                showingNoteSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Add Context")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.cardBackground)
                        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.overlay.opacity(0.2), lineWidth: 1)
                )
            }
            
            Button {
                generateSchedule()
            } label: {
                HStack(spacing: 8) {
                    if contentModel.isGeneratingSchedule || contentModel.showingThinkingOverlay {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    
                    Text((contentModel.isGeneratingSchedule || contentModel.showingThinkingOverlay) ? "Generating..." : "Generate Schedule")
                        .font(.system(size: 15, weight: .semibold))
                }
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
            .disabled(contentModel.isGeneratingSchedule || contentModel.showingThinkingOverlay)
            .scaleEffect((contentModel.isGeneratingSchedule || contentModel.showingThinkingOverlay) ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: contentModel.isGeneratingSchedule || contentModel.showingThinkingOverlay)
        }
    }

    private var timelineScheduleContentView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 20) {
                currentEventSection
                upcomingEventsSection
                dayOverviewSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .opacity(contentModel.showingThinkingOverlay ? 0.3 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: contentModel.showingThinkingOverlay)
    }

    private var calendarContentView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                currentEventSection
                simpleCalendarTimelineView
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .opacity(contentModel.showingThinkingOverlay ? 0.3 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: contentModel.showingThinkingOverlay)
    }

    // MARK: - Current Event Section
    private var currentEventSection: some View {
        TimelineView(.periodic(from: Date(), by: 1.0)) { context in
            if let currentEvent = getCurrentEvent(at: context.date) {
                VStack(spacing: 12) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(currentEvent.color)
                                .frame(width: 6, height: 6)
                            Text("In Progress")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(currentEvent.color)
                        }
                        
                        Spacer()
                        
                        Text(timeRemainingText(for: currentEvent, at: context.date))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.cardBackground)
                                    .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
                            )
                    }
                    
                    currentEventCard(currentEvent, at: context.date)
                        .transition(.scale.combined(with: .opacity))
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentEvent.id)
            }
        }
    }
    
    private func currentEventCard(_ event: Event, at currentTime: Date) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Icon with refined styling
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: event.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    )
                    .matchedGeometryEffect(id: "eventIcon", in: eventCardAnimation, isSource: !showingFocusMode)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .matchedGeometryEffect(id: "eventTime", in: eventCardAnimation, isSource: !showingFocusMode)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(progressForEvent(event, at: currentTime) * 100))%")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .matchedGeometryEffect(id: "eventProgress", in: eventCardAnimation, isSource: !showingFocusMode)
                    
                    Text("Complete")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(event.color.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(event.color.opacity(0.4), lineWidth: 0.5)
                    )
                    .matchedGeometryEffect(id: "eventBackground", in: eventCardAnimation, isSource: !showingFocusMode)
            )
            .onTapGesture {
                focusEvent = event
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showingFocusMode = true
                }
            }
            
            // Progress bar with refined styling
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(.white.opacity(0.9))
                        .frame(width: geometry.size.width * progressForEvent(event, at: currentTime))
                    
                    Rectangle()
                        .fill(.white.opacity(0.2))
                }
            }
            .frame(height: 3)
            .matchedGeometryEffect(id: "eventProgressBar", in: eventCardAnimation, isSource: !showingFocusMode)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: event.color.opacity(0.3), radius: 12, y: 6)
        .fullScreenCover(isPresented: $showingFocusMode) {
            if let focusEvent = focusEvent {
                FocusModeView(
                    event: focusEvent,
                    isPresented: $showingFocusMode,
                    animationNamespace: eventCardAnimation
                )
                .onDisappear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.focusEvent = nil
                    }
                }
            }
        }
        .onChange(of: getCurrentEvent(at: Date())) { (oldEvent: Event?, newEvent: Event?) in
            if showingFocusMode && focusEvent?.id != newEvent?.id {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showingFocusMode = false
                }
            }
        }
    }

    // MARK: - Upcoming Events Section
    private var upcomingEventsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Upcoming")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                if visibleEvents.count > 3 {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showAllUpcomingEvents.toggle()
                        }
                    } label: {
                        Text(showAllUpcomingEvents ? "Show Less" : "View All (\(visibleEvents.count))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.accent.opacity(0.1))
                            )
                    }
                }
            }
            
            LazyVStack(spacing: 8) {
                let eventsToShow = showAllUpcomingEvents ? visibleEvents : Array(visibleEvents.prefix(3))
                ForEach(eventsToShow, id: \.id) { event in
                    upcomingEventCard(event)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
        )
    }

    private func upcomingEventCard(_ event: Event) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text(event.start.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(event.end.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(width: 60)
            
            Rectangle()
                .fill(event.color)
                .frame(width: 3)
                .frame(maxHeight: .infinity)
            
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(event.color.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: event.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(event.color)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(durationText(for: event))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(event.color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(event.color.opacity(0.4), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Day Overview Section
    private var dayOverviewSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Day Overview")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                Image(systemName: "chart.pie")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            ZStack {
                pieChartView
                    .frame(width: 160, height: 160)
                
                if let selectedSlice = selectedPieSlice {
                    pieSlicePopup(slice: selectedSlice)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            pieChartLegendGrid
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPieSlice = nil
            }
        }
    }

    // MARK: - Pie Chart View
    private var pieChartView: some View {
        ZStack {
            ForEach(Array(pieChartData.enumerated()), id: \.element.id) { index, slice in
                pieSlice(
                    startAngle: slice.startAngle,
                    endAngle: slice.endAngle,
                    color: slice.color,
                    slice: slice
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPieSlice = selectedPieSlice?.id == slice.id ? nil : slice
                    }
                }
            }
            
            Circle()
                .fill(AppTheme.Colors.cardBackground)
                .frame(width: 70, height: 70)
            
            VStack(spacing: 1) {
                Text(totalTimeText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Total")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Pie Slice Helper Function
    private func pieSlice(startAngle: Angle, endAngle: Angle, color: Color, slice: PieChartSlice) -> some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let isSelected = selectedPieSlice?.id == slice.id
            
            Path { path in
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle - Angle(degrees: 90),
                    endAngle: endAngle - Angle(degrees: 90),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(isSelected ? color.opacity(0.8) : color)
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .overlay(
                Path { path in
                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: startAngle - Angle(degrees: 90),
                        endAngle: endAngle - Angle(degrees: 90),
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                .stroke(Color.white.opacity(0.5), lineWidth: isSelected ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
    }

    // MARK: - Pie Chart Legend Grid
    private var pieChartLegendGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
        
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(pieChartData.prefix(6), id: \.id) { slice in
                HStack(spacing: 6) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(slice.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                        
                        Text(slice.timeText)
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.Colors.background.opacity(0.5))
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPieSlice = selectedPieSlice?.id == slice.id ? nil : slice
                    }
                }
            }
        }
    }

    // MARK: - Pie Slice Popup
    private func pieSlicePopup(slice: PieChartSlice) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(slice.color)
                    .frame(width: 8, height: 8)
                
                Text(slice.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPieSlice = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text(slice.timeText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Duration")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                VStack(spacing: 2) {
                    Text("\(Int(slice.percentage))%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(slice.color)
                    
                    Text("of Day")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                VStack(spacing: 2) {
                    Text("\(slice.count)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Events")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            if !slice.events.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Events:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    ForEach(slice.events.prefix(3), id: \.id) { event in
                        HStack(spacing: 6) {
                            Image(systemName: event.icon)
                                .font(.system(size: 9))
                                .foregroundColor(slice.color)
                                .frame(width: 12)
                            
                            Text(event.title)
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(durationText(for: event))
                                .font(.system(size: 9))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                    }
                    
                    if slice.events.count > 3 {
                        Text("+ \(slice.events.count - 3) more")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .padding(.leading, 18)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.Colors.background)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(slice.color.opacity(0.2), lineWidth: 1)
        )
        .frame(width: 240)
        .offset(y: -35)
    }

    // MARK: - Calendar View
    private var simpleCalendarTimelineView: some View {
        TimelineView(.periodic(from: Date(), by: 60.0)) { context in
            let currentTime = context.date
            
            VStack(spacing: 16) {
                HStack {
                    Text("Timeline")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    
                    Spacer()
                    
                    Text(currentTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.accent.opacity(0.1))
                        )
                }
                
                calendarTimelineContent(currentTime: currentTime)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Colors.cardBackground)
                    .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
            )
        }
    }

    // MARK: - Calendar Timeline Content
    private func calendarTimelineContent(currentTime: Date) -> some View {
        let timeColumnWidth: CGFloat = 60
        let hourHeight: CGFloat = 100  // Increased from 80 to give more space
        
        let userScheduleBounds = getUserScheduleBounds()
        let startHour = userScheduleBounds.startHour
        let endHour = userScheduleBounds.endHour
        let totalHours = endHour - startHour
        
        return GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let eventAreaWidth = totalWidth - timeColumnWidth - 16
            
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ForEach(startHour..<endHour, id: \.self) { hour in
                            calendarHourRow(
                                hour: hour,
                                currentTime: currentTime,
                                timeColumnWidth: timeColumnWidth,
                                eventAreaWidth: eventAreaWidth,
                                hourHeight: hourHeight
                            )
                        }
                    }
                    
                    ForEach(allCalendarEvents, id: \.id) { event in
                        calendarEventBlock(
                            event: event,
                            currentTime: currentTime,
                            timeColumnWidth: timeColumnWidth,
                            eventAreaWidth: eventAreaWidth,
                            hourHeight: hourHeight,
                            startHour: startHour
                        )
                    }
                }
            }
        }
        .frame(height: CGFloat(totalHours) * hourHeight)
    }

    private var allCalendarEvents: [Event] {
        // Only return actual scheduled events, no wake/bedtime events
        return events.filter { !$0.title.contains("NGTime") }
            .sorted { $0.start < $1.start }
    }

    private func calendarHourRow(
        hour: Int,
        currentTime: Date,
        timeColumnWidth: CGFloat,
        eventAreaWidth: CGFloat,
        hourHeight: CGFloat
    ) -> some View {
        let displayHour = hour >= 24 ? hour - 24 : hour
        let hourDate = Calendar.current.date(bySettingHour: displayHour, minute: 0, second: 0, of: currentTime) ?? currentTime
        
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(hourDate.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .frame(width: timeColumnWidth, alignment: .leading)
            
            VStack(spacing: 0) {
                Rectangle()
                    .fill(AppTheme.Colors.overlay.opacity(0.15))
                    .frame(height: 1)
                
                Spacer()
                    .frame(height: hourHeight / 2 - 1)
                
                Rectangle()
                    .fill(AppTheme.Colors.overlay.opacity(0.08))
                    .frame(height: 1)
                
                Spacer()
                    .frame(height: hourHeight / 2 - 1)
            }
            .frame(width: eventAreaWidth, height: hourHeight)
        }
        .frame(height: hourHeight)
    }

    private func calendarEventBlock(
        event: Event,
        currentTime: Date,
        timeColumnWidth: CGFloat,
        eventAreaWidth: CGFloat,
        hourHeight: CGFloat,
        startHour: Int
    ) -> some View {
        let position = calculateEventPosition(
            event: event,
            hourHeight: hourHeight,
            startHour: startHour
        )
        
        let isActive = currentTime >= event.start && currentTime <= event.end
        let isPast = currentTime > event.end
        
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                // Time column
                VStack(spacing: 1) {
                    Text(event.start.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(event.end.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(width: 50, alignment: .leading)
                
                // Color indicator
                Rectangle()
                    .fill(event.color)
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
                    .opacity(isActive ? 1.0 : 0.8)
                
                // Event content with more space
                HStack(spacing: 8) {
                    // Icon
                    RoundedRectangle(cornerRadius: 6)
                        .fill(event.color.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: event.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(event.color)
                        )
                    
                    // Event details with flexible width
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(position.height > 60 ? 2 : 1)
                            .multilineTextAlignment(.leading)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text(durationText(for: event))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Status indicator for active events
                    if isActive {
                        VStack(spacing: 1) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            
                            Text("Live")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color.green)
                        }
                    }
                }
            }
            
            // Add breathing room for larger events
            if position.height > 80 {
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: eventAreaWidth - 4, height: max(position.height, 50))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(event.color.opacity(isActive ? 0.12 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            event.color.opacity(isActive ? 0.6 : 0.3),
                            lineWidth: isActive ? 1.5 : 1
                        )
                )
        )
        .opacity(isPast ? 0.65 : 1.0)
        .scaleEffect(isActive ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .offset(
            x: timeColumnWidth + 12,
            y: position.yOffset
        )
    }

    private func calculateEventPosition(
        event: Event,
        hourHeight: CGFloat,
        startHour: Int
    ) -> (yOffset: CGFloat, height: CGFloat) {
        let calendar = Calendar.current
        
        let startHour24 = calendar.component(.hour, from: event.start)
        let startMinute = calendar.component(.minute, from: event.start)
        let endHour24 = calendar.component(.hour, from: event.end)
        let endMinute = calendar.component(.minute, from: event.end)
        
        let startHourPosition = startHour24 >= startHour ? startHour24 - startHour : (24 - startHour) + startHour24
        
        let endHourPosition = endHour24 >= startHour ? endHour24 - startHour : (24 - startHour) + endHour24
        
        let startTotalMinutes = startHourPosition * 60 + startMinute
        let endTotalMinutes = endHourPosition * 60 + endMinute
        
        let minutesPerPixel = hourHeight / 60.0
        let yOffset = CGFloat(startTotalMinutes) * minutesPerPixel
        let height = max(CGFloat(endTotalMinutes - startTotalMinutes) * minutesPerPixel, 36.0)
        
        return (yOffset: yOffset, height: height)
    }

    private func getUserScheduleBounds() -> (startHour: Int, endHour: Int) {
        guard !allCalendarEvents.isEmpty else {
            return (startHour: 6, endHour: 22) // Default reasonable bounds
        }
        
        // Calculate bounds based on actual events
        let sortedEvents = allCalendarEvents.sorted { $0.start < $1.start }
        let earliestHour = Calendar.current.component(.hour, from: sortedEvents.first?.start ?? Date())
        let latestHour = Calendar.current.component(.hour, from: sortedEvents.last?.end ?? Date())
        
        // Add buffer hours around actual events
        let startHour = max(0, earliestHour - 1)
        let endHour = min(24, latestHour + 2)
        
        return (startHour: startHour, endHour: endHour)
    }

    // MARK: - Note Input Sheet
    private var noteInputSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Context")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Provide additional context or preferences for your schedule generation.")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineSpacing(2)
                }
                
                TextEditor(text: $userNote)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.Colors.cardBackground)
                            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                    )
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.Colors.overlay.opacity(0.2), lineWidth: 1)
                    )
                
                Spacer()
            }
            .padding(24)
            .background(AppTheme.Colors.background)
            .navigationTitle("Context Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingNoteSheet = false
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        showingNoteSheet = false
                    }
                    .foregroundColor(AppTheme.Colors.accent)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - AI Thinking Content Overlay
    private var aiThinkingContentOverlay: some View {
        ZStack {
            // Semi-transparent background only over content
            AppTheme.Colors.background.opacity(0.95)
                .ignoresSafeArea(.all, edges: [])
            
            aiThinkingContent
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private var aiThinkingContent: some View {
        VStack(spacing: 24) {
            // AI Brain animation
            aiThinkingBrainAnimation
            
            // Thinking steps
            aiThinkingSteps
            
            // Progress indicator
            aiThinkingProgressIndicator
        }
        .padding(.horizontal, 32)
    }
    
    private var aiThinkingBrainAnimation: some View {
        VStack(spacing: 16) {
            ZStack {
                // Pulsing circles
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(AppTheme.Colors.accent.opacity(0.3), lineWidth: 2)
                        .frame(width: 60 + CGFloat(index * 20), height: 60 + CGFloat(index * 20))
                        .scaleEffect(1.0 + CGFloat(index) * 0.1)
                        .opacity(0.7 - Double(index) * 0.2)
                        .animation(
                            .easeInOut(duration: 1.5 + Double(index) * 0.3)
                            .repeatForever(autoreverses: true),
                            value: contentModel.showingThinkingOverlay
                        )
                }
                
                // Central brain icon
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.accent,
                                AppTheme.Colors.accent.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                    )
                    .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 12, y: 4)
            }
            
            Text("TimeFlow AI")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }
    
    private var aiThinkingSteps: some View {
        VStack(spacing: 16) {
            Text("Generating your perfect schedule...")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Current thinking step - now using ContentModel state
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(AppTheme.Colors.accent)
                
                Text(contentModel.currentThinkingStep)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.cardBackground)
                    .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.Colors.accent.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var aiThinkingProgressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index <= contentModel.thinkingStepIndex ? AppTheme.Colors.accent : AppTheme.Colors.overlay.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: contentModel.thinkingStepIndex)
            }
        }
    }

    // MARK: - All remaining functions stay the same
    private var visibleEvents: [Event] {
        let now = Date()
        return events.filter { event in
            event.start > now && !event.title.contains("NGTime")
        }.sorted { $0.start < $1.start }
    }
    
    private func getCurrentEvent(at time: Date = Date()) -> Event? {
        return events.first { event in
            time >= event.start && time <= event.end && !event.title.contains("NGTime")
        }
    }
    
    private func timeRemainingText(for event: Event, at currentTime: Date = Date()) -> String {
        let remaining = event.end.timeIntervalSince(currentTime)
        let totalMinutes = Int(ceil(remaining / 60))
        
        if totalMinutes <= 0 {
            return "Ending soon"
        } else if totalMinutes < 60 {
            return "\(totalMinutes)m left"
        } else {
            let hours = totalMinutes / 60
            let remainingMinutes = totalMinutes % 60
            return "\(hours)h \(remainingMinutes)m left"
        }
    }
    
    private func durationText(for event: Event) -> String {
        let roundedMinutes = roundedMinutesForEvent(event)
        return formatMinutesToTimeText(roundedMinutes)
    }
    
    private func progressForEvent(_ event: Event, at currentTime: Date = Date()) -> Double {
        let total = event.end.timeIntervalSince(event.start)
        let elapsed = currentTime.timeIntervalSince(event.start)
        let progress = elapsed / total
        
        return max(0, min(progress, 1))
    }
    
    private func roundedMinutesForEvent(_ event: Event) -> Int {
        let eventMinutes = Int(round(event.end.timeIntervalSince(event.start) / 60))
        // Round to nearest 5 minutes, minimum 5 minutes
        let roundedMinutes = max(5, ((eventMinutes + 2) / 5) * 5)
        return roundedMinutes
    }
    
    private func formatMinutesToTimeText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 && remainingMinutes > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    // Helper function to calculate total awake minutes
    private func calculateTotalAwakeMinutes() -> Int {
        guard let user = contentModel.user else { return 960 } // Default to 16 hours
        
        let awakeHours = user.todaysAwakeHours ?? user.awakeHours
        let wakeTimeString = awakeHours.wakeTime
        let sleepTimeString = awakeHours.sleepTime
        
        // Parse wake time
        let wakeComponents = wakeTimeString.split(separator: ":").compactMap { Int($0) }
        guard wakeComponents.count == 2 else { return 960 }
        
        let wakeMinutes = wakeComponents[0] * 60 + wakeComponents[1]
        
        // Parse sleep time
        let sleepComponents = sleepTimeString.split(separator: ":").compactMap { Int($0) }
        guard sleepComponents.count == 2 else { return 960 }
        
        let sleepMinutes = sleepComponents[0] * 60 + sleepComponents[1]
        
        // Calculate total awake minutes
        if sleepMinutes > wakeMinutes {
            // Same day (e.g., wake at 7:00, sleep at 23:00)
            return sleepMinutes - wakeMinutes
        } else {
            // Sleep time is next day (e.g., wake at 7:00, sleep at 1:00)
            return (24 * 60) - wakeMinutes + sleepMinutes
        }
    }
    
    private func loadScheduleData() {
        if let user = contentModel.user {
            events = user.currentSchedule
            return
        }
        
        if let completedEvents = contentModel.checkForCompletedSchedule(), !completedEvents.isEmpty {
            events = completedEvents
            return
        }
        
        events = []
    }
    
    // MARK: - Pie Chart Data Structure
    private struct PieChartSlice: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
        let totalMinutes: Int
        let timeText: String
        let percentage: Double
        let color: Color
        let startAngle: Angle
        let endAngle: Angle
        let events: [Event]
    }

    // MARK: - Pie Chart Data Computation
    private var pieChartData: [PieChartSlice] {
        let eventsByType = Dictionary(grouping: allDayEvents) { $0.eventType }
        let scheduledMinutes = allDayEvents.reduce(0) { total, event in
            return total + roundedMinutesForEvent(event)
        }
        
        // Calculate total awake minutes and unscheduled time
        let totalAwakeMinutes = calculateTotalAwakeMinutes()
        let unscheduledMinutes = max(0, totalAwakeMinutes - scheduledMinutes)
        let totalMinutes = scheduledMinutes + unscheduledMinutes
        
        guard totalMinutes > 0 else { return [] }
        
        var currentAngle: Double = 0
        var slices: [PieChartSlice] = []
        
        let sortedTypes = eventsByType.sorted { 
            let time1 = $0.value.reduce(0) { total, event in
                return total + roundedMinutesForEvent(event)
            }
            let time2 = $1.value.reduce(0) { total, event in
                return total + roundedMinutesForEvent(event)
            }
            return time1 > time2
        }
        
        // Add slices for scheduled events
        for (eventType, events) in sortedTypes {
            let typeMinutes = events.reduce(0) { total, event in
                return total + roundedMinutesForEvent(event)
            }
            
            let percentage = (Double(typeMinutes) / Double(totalMinutes)) * 100
            let angleSize = (Double(typeMinutes) / Double(totalMinutes)) * 360
            
            let timeText = formatMinutesToTimeText(typeMinutes)
            let cleanLabel = eventType == .recurringCommitment ? "Commitment" : eventType.rawValue
            
            let slice = PieChartSlice(
                label: cleanLabel,
                count: events.count,
                totalMinutes: typeMinutes,
                timeText: timeText,
                percentage: percentage,
                color: eventTypeColor(eventType),
                startAngle: Angle(degrees: currentAngle),
                endAngle: Angle(degrees: currentAngle + angleSize),
                events: events
            )
            
            slices.append(slice)
            currentAngle += angleSize
        }
        
        // Add unscheduled time slice if there's any
        if unscheduledMinutes > 0 {
            let percentage = (Double(unscheduledMinutes) / Double(totalMinutes)) * 100
            let angleSize = (Double(unscheduledMinutes) / Double(totalMinutes)) * 360
            
            let timeText = formatMinutesToTimeText(unscheduledMinutes)
            
            let unscheduledSlice = PieChartSlice(
                label: "Unscheduled",
                count: 0,
                totalMinutes: unscheduledMinutes,
                timeText: timeText,
                percentage: percentage,
                color: AppTheme.Colors.textTertiary.opacity(0.6),
                startAngle: Angle(degrees: currentAngle),
                endAngle: Angle(degrees: currentAngle + angleSize),
                events: []
            )
            
            slices.append(unscheduledSlice)
        }
        
        return slices
    }

    private var totalTimeText: String {
        let totalMinutes = calculateTotalAwakeMinutes()
        return formatMinutesToTimeText(totalMinutes)
    }
    
    private var allDayEvents: [Event] {
        return events.filter { !$0.title.contains("NGTime") }
    }

    private func eventTypeColor(_ type: EventType) -> Color {
        switch type {
        case .school, .collegeClass:
            return .blue
        case .work:
            return .indigo
        case .goal:
            return .purple
        case .assignment, .testStudy:
            return .orange
        case .meal:
            return .green
        case .recurringCommitment:
            return .pink
        case .other:
            return .gray
        }
    }
    
    // MARK: - Generate Schedule
    private func generateSchedule() {
        guard contentModel.user != nil else {
            if contentModel.loggedIn {
                Task {
                    do {
                        try await contentModel.fetchUser()
                        await MainActor.run {
                            if contentModel.user != nil {
                                generateSchedule()
                            }
                        }
                    } catch {
                        print("❌ Failed to fetch user: \(error)")
                    }
                }
            }
            return
        }
        
        Task {
            do {
                let responseEvents = try await contentModel.generateScheduleWithBackgroundSupport(userNote: userNote)
                
                await MainActor.run {
                    events = responseEvents
                    contentModel.user?.currentSchedule = responseEvents
                    Task {
                        do {
                            try await contentModel.saveUserInfo()
                        } catch {
                            print("❌ Failed to save to Firebase: \(error)")
                        }
                    }
                }
            
            } catch {
                await MainActor.run {
                    print("❌ Schedule generation failed: \(error)")
                }
            }
        }
    }
}