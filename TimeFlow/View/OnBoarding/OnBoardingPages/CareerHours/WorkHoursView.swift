//
//  WorkHoursView.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/29/25.
//


import SwiftUI

struct WorkHoursView: View {
    
    @Binding var rows: [DayHours]
    let themeColor: Color
    
    @State private var copyAlert = false
    
    private let card = Color(red: 0.13, green: 0.13, blue: 0.15)
    
    private var valid: Bool {
        rows.filter(\.enabled).allSatisfy { $0.endTime > $0.startTime }
    }
    
    var onContinue: () -> Void = {}
    
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

            VStack(spacing: 28) {
                header
                
                ScrollView {
                    VStack(spacing: 18) {
                        ForEach($rows) { $row in
                            rowCard($row)
                        }
                    }
                    .padding(.horizontal)
                }
                .scaleEffect(animateContent ? 1.0 : 0.8)
                .opacity(animateContent ? 1.0 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
                
                Button("Copy Monday to Tue–Fri") { copyAlert = true }
                    .font(.subheadline.weight(.semibold))
                    .disabled(!rows.first!.enabled)
                    .tint(themeColor)
                
                continueButton
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { progressToolbar(currentStep: 2) {
            onContinue()
        } }
        .alert("Copy Monday's hours to Tue–Fri?",
               isPresented: $copyAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Copy", role: .destructive) { copyMonday() }
        }
        .onAppear {
            withAnimation {
                animateContent = true
            }
        }
    }
    
}

// MARK: sub-views
private extension WorkHoursView {
    
    
    
    var header: some View {
        VStack(spacing: 8) {
            Text("Set your core work hours")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("We'll avoid scheduling personal tasks inside this window.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal)
        }
        .opacity(animateContent ? 1.0 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.easeOut(duration: 0.8), value: animateContent)
    }
    
    private func rowCard(_ binding: Binding<DayHours>) -> some View {
            
        let startDate = Binding<Date>(
            get: { Date.at(binding.startTime.wrappedValue) },
            set: { binding.startTime.wrappedValue = $0.hhmmString }
        )
        let endDate = Binding<Date>(
            get: { Date.at(binding.endTime.wrappedValue) },
            set: { binding.endTime.wrappedValue = $0.hhmmString }
        )
        
        return VStack(alignment: .leading, spacing: 14) {
            Toggle(binding.day.wrappedValue.rawValue, isOn: binding.enabled)
                .toggleStyle(.switch)
                .font(.headline)
                .tint(themeColor)
                .foregroundColor(.white)
            
            if binding.enabled.wrappedValue {
                HStack {
                    DatePicker("", selection: startDate,
                               displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    
                    DatePicker("", selection: endDate,
                               displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.13, green: 0.13, blue: 0.15))
                .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
        )
    }
    
    var continueButton: some View {
        Button(action: onContinue) {
            Text("Continue")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(valid ? themeColor : Color.gray.opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(16)
        }
        .disabled(!valid)
        .padding(.horizontal)
        .padding(.bottom, 26)
    }
    
    func copyMonday() {
        guard let mon = rows.first else { return }
        for i in 1...4 {
            rows[i].enabled = mon.enabled
            rows[i].startTime   = mon.startTime
            rows[i].endTime     = mon.endTime
        }
    }
}


#Preview {
    WorkHoursView(rows: .constant([]), themeColor: .blue)
}
