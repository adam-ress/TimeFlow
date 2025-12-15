//  SchoolHoursView.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/28/25.
//

import SwiftUI

struct SchoolHoursView: View {
    
    @Binding var startTime: String
    @Binding var endTime: String
    let themeColor: Color
    
    @State private var startHour: CGFloat = 8.0   // 8am
    @State private var endHour: CGFloat = 15.0    // 3pm
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @State private var animateCards = false
    
    @State private var startDragInitial: CGFloat = 0.0
    @State private var endDragInitial: CGFloat = 0.0
    
    // 6am to 4pm range
    private let trackHeight: CGFloat = 400.0
    private let minHour: CGFloat = 6.0
    private let maxHour: CGFloat = 16.0
    
    private var hourRange: CGFloat {
        maxHour - minHour
    }
    
    private var startOffset: CGFloat {
        ((startHour - minHour) / hourRange) * trackHeight
    }
    
    private var endOffset: CGFloat {
        ((endHour - minHour) / hourRange) * trackHeight
    }
    
    private var validRange: Bool { endHour > startHour + 0.25 }
    
    var onContinue: () -> Void = {}
    
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
            
            VStack(spacing: 0) {
                header
                
                Spacer()
                    .frame(height: 40)
                
                // Single grouped card
                VStack(spacing: 20) {
                    Text("School hours")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    verticalTimeBarPicker
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            (isDraggingStart || isDraggingEnd) ? themeColor : Color.clear,
                            lineWidth: 2
                        )
                        .shadow(
                            color: (isDraggingStart || isDraggingEnd) ? themeColor.opacity(0.3) : Color.clear,
                            radius: (isDraggingStart || isDraggingEnd) ? 8 : 0
                        )
                        .animation(.easeInOut(duration: 0.2), value: isDraggingStart || isDraggingEnd)
                )
                .padding(.horizontal, 24)
                .scaleEffect(animateCards ? 1.0 : 0.8)
                .opacity(animateCards ? 1.0 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateCards)
                .padding(.bottom, 20)
                
                Spacer()
                
                continueButton
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { progressToolbar(currentStep: 2) {
            onContinue()
        } }
        .onAppear {
            withAnimation {
                animateCards = true
            }
            updateTimes()
        }
    }
    
    private func updateTimes() {
        startTime = formatTime(startHour)
        endTime = formatTime(endHour)
    }
    
    private func formatTime(_ hour: CGFloat) -> String {
        let totalMinutes = round(hour * 60.0)
        let hourInt = Int(totalMinutes / 60)
        let mins = Int(totalMinutes.truncatingRemainder(dividingBy: 60))
        let displayHour = hourInt % 12 == 0 ? 12 : hourInt % 12
        let ampm = hourInt >= 12 ? "PM" : "AM"
        
        return "\(displayHour):\(String(format: "%02d", mins)) \(ampm)"
    }
    
    private func formatTimeDisplay(_ hour: CGFloat) -> String {
        let totalMinutes = round(hour * 60.0)
        let hourInt = Int(totalMinutes / 60)
        let mins = Int(totalMinutes.truncatingRemainder(dividingBy: 60))
        let displayHour = hourInt % 12 == 0 ? 12 : hourInt % 12
        let ampm = hourInt >= 12 ? "PM" : "AM"
        
        return "\(displayHour):\(String(format: "%02d", mins)) \(ampm)"
    }
    
    private func snapToFifteenMinutes(_ hour: CGFloat) -> CGFloat {
        return round(hour * 4.0) / 4.0
    }
    
    var header: some View {
        VStack(spacing: 12) {
            Text("When are you in school?")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            Text("We'll protect these hours Monday–Friday")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
        }
        .padding(.top, 40)
        .opacity(animateCards ? 1.0 : 0)
        .offset(y: animateCards ? 0 : -20)
        .animation(.easeOut(duration: 0.8), value: animateCards)
    }
    
    private var verticalTimeBarPicker: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                timeLabels
                    .frame(width: 60)
                timeTrackContainer
                    .frame(width: 200, height: trackHeight)
            }
            
            if !validRange {
                Text("End time must be at least 15 minutes after start time")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
    }
    
    private var timeLabels: some View {
        VStack(spacing: 0) {
            ForEach(Array(stride(from: 6, through: 16, by: 2)), id: \.self) { hour in
                let displayHour = hour > 12 ? hour - 12 : hour
                let ampm = hour >= 12 ? "PM" : "AM"
                Text("\(displayHour) \(ampm)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                if hour != 16 {
                    Spacer()
                }
            }
        }
    }
    
    private var timeTrackContainer: some View {
        ZStack(alignment: .center) {
            hourTicks
            backgroundTrack
            selectedRange
            startThumb
            endThumb
        }
        .frame(width: 200, height: trackHeight)
    }
    
    private var hourTicks: some View {
        Group {
            // Major ticks every hour
            ForEach(6...16, id: \.self) { hour in
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 100, height: 1)
                    .offset(y: ((CGFloat(hour) - minHour) / hourRange * trackHeight) - trackHeight / 2)
            }
            
            // Minor ticks every 30 minutes
            ForEach(Array(stride(from: 6.5, through: 15.5, by: 1.0)), id: \.self) { half in
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 80, height: 1)
                    .offset(y: ((half - minHour) / hourRange * trackHeight) - trackHeight / 2)
            }
        }
    }
    
    private var backgroundTrack: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 40, height: trackHeight)
    }
    
    private var selectedRange: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(themeColor.opacity(0.3))
            .frame(width: 40, height: max(0, endOffset - startOffset))
            .offset(y: (startOffset + endOffset) / 2 - trackHeight / 2)
    }
    
    private var startThumb: some View {
        HStack {
            Text(formatTimeDisplay(startHour))
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(themeColor.opacity(0.8))
                .cornerRadius(8)
                .foregroundColor(.white)
                .transition(.opacity)
        }
        .scaleEffect(isDraggingStart ? 1.2 : 1.0)
        .offset(y: startOffset - trackHeight / 2)
        .gesture(startDragGesture)
    }

    private var endThumb: some View {
        HStack {
            Text(formatTimeDisplay(endHour))
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(themeColor.opacity(0.8))
                .cornerRadius(8)
                .foregroundColor(.white)
                .transition(.opacity)
        }
        .scaleEffect(isDraggingEnd ? 1.2 : 1.0)
        .offset(y: endOffset - trackHeight / 2)
        .gesture(endDragGesture)
    }
    
    private var startDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDraggingStart {
                    isDraggingStart = true
                    startDragInitial = startHour
                }
                
                let delta = value.translation.height / trackHeight * hourRange
                var newHour = startDragInitial + delta
                newHour = max(minHour, min(endHour - 0.25, newHour))
                let snappedHour = snapToFifteenMinutes(newHour)
                startHour = snappedHour
                updateTimes()
            }
            .onEnded { _ in
                isDraggingStart = false
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
    }
    
    private var endDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDraggingEnd {
                    isDraggingEnd = true
                    endDragInitial = endHour
                }
                
                let delta = value.translation.height / trackHeight * hourRange
                var newHour = endDragInitial + delta
                newHour = min(maxHour, max(startHour + 0.25, newHour))
                let snappedHour = snapToFifteenMinutes(newHour)
                endHour = snappedHour
                updateTimes()
            }
            .onEnded { _ in
                isDraggingEnd = false
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
    }
    
    var continueButton: some View {
        Button {
            if validRange {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onContinue()
            }
        } label: {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(validRange ? themeColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .disabled(!validRange)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
}

#Preview {
    NavigationStack {
        SchoolHoursView(startTime: .constant("08:00"), endTime: .constant("15:00"), themeColor: .blue)
    }
}
