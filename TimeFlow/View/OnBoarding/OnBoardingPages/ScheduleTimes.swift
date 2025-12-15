import SwiftUI

struct ScheduleTimes: View {
    
    @Binding var awakeHours: AwakeHours
    let themeColor: Color
    
    var onContinue: () -> Void = {}
    
    @State private var wakeMin: Double
    @State private var bedMin: Double
    
    private let sleepHours: Double = 8.0 // Fixed for display purposes
    
    @State private var animateContent = false
    
    init(awakeHours: Binding<AwakeHours>, themeColor: Color, onContinue: @escaping () -> Void = {}) {
        self._awakeHours = awakeHours
        self.themeColor = themeColor
        self.onContinue = onContinue
        
        let initialWake = toMinutes(awakeHours.wrappedValue.wakeTime)
        let initialBed = toMinutes(awakeHours.wrappedValue.sleepTime)
        
        self._wakeMin = State(initialValue: initialWake)
        self._bedMin = State(initialValue: initialBed)
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    AppTheme.Colors.secondary.opacity(0.3),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                
                Spacer()
                
                header
                
                Spacer()
                
                BedtimeDial(wake: $wakeMin, bed: $bedMin, accent: themeColor)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .scaleEffect(animateContent ? 1.0 : 0.8)
                    .opacity(animateContent ? 1.0 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [themeColor, themeColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: themeColor.opacity(0.3), radius: 8, y: 4)
                        )
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 44)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("Step 3 of 6")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .onChange(of: wakeMin) { oldValue, newValue in
            enforceMinSeparation()
            awakeHours.wakeTime = toHHMM(from: newValue)
        }
        .onChange(of: bedMin) { oldValue, newValue in
            enforceMinSeparation()
            awakeHours.sleepTime = toHHMM(from: newValue)
        }
        .onAppear {
            withAnimation {
                animateContent = true
            }
        }
    }
    
    private func enforceMinSeparation() {
        let minSeparation: Double = 60  // At least 1 hour apart
        let diff = (wakeMin - bedMin + 1440).truncatingRemainder(dividingBy: 1440)
        if diff < minSeparation {
            bedMin = (wakeMin - minSeparation + 1440).truncatingRemainder(dividingBy: 1440)
        } else if diff > 1440 - minSeparation {
            wakeMin = (bedMin + minSeparation).truncatingRemainder(dividingBy: 1440)
        }
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            Text("What are your day hours?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Set your typical wake-up and bedtime for school or work days")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .opacity(animateContent ? 1.0 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.easeOut(duration: 0.8), value: animateContent)
    }
}

struct BedtimeDial: View {
    @Binding var wake: Double
    @Binding var bed: Double
    
    let accent: Color
    
    private let stroke: CGFloat = 24
    private let knob: CGFloat = 40
    private let hourTickHeight: CGFloat = 12
    private let labelOffset: CGFloat = 32
    
    // Define colors
    private let sunColor = Color.yellow
    private let moonColor = Color(red: 0.4, green: 0.2, blue: 0.8) // Dark purple
    
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = (side - knob - labelOffset) / 2
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            
            ZStack {
                dial(radius: radius)
                sleepArc(radius: radius, centre: centre)
                knob(minutes: $bed, symbol: "moon.fill", color: moonColor, radius: radius, centre: centre)
                knob(minutes: $wake, symbol: "sun.max.fill", color: sunColor, radius: radius, centre: centre)
                centreTimes
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Day hours dial. Wake at \(timeString(from: wake)), Bed at \(timeString(from: bed))")
    }
    
    private func dial(radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    Circle()
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color(.black).opacity(0.1), radius: 8, y: 4)
            
            // Only show major hour markers (every 4 hours: 12, 4, 8)
            ForEach([0, 4, 8, 12, 16, 20], id: \.self) { hour in
                hourTickAndLabel(hour: hour, radius: radius)
            }
        }
    }
    
    private func hourTickAndLabel(hour: Int, radius: CGFloat) -> some View {
        let rotation = Double(hour) * 15 // 360/24 = 15 degrees per hour
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let period = hour < 12 ? "AM" : "PM"
        
        return ZStack {
            Rectangle()
                .fill(Color(.label).opacity(0.4))
                .frame(width: 2, height: hourTickHeight)
                .offset(y: -radius + hourTickHeight / 2)
            
            VStack(spacing: 2) {
                Text("\(displayHour)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.label))
                Text(period)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
            }
            .offset(y: -radius - labelOffset / 2 + 4)
        }
        .rotationEffect(.degrees(rotation))
    }
    
    private func sleepArc(radius: CGFloat, centre: CGPoint) -> some View {
        let startAngle = Angle(degrees: angle(for: bed) - 90)
        let endAngle = Angle(degrees: angle(for: wake) - 90)
        let clockwise = (wake - bed + 1440).truncatingRemainder(dividingBy: 1440) <= 720  // Changed > to <=
        
        return Path { p in
            p.addArc(center: centre,
                     radius: radius,
                     startAngle: startAngle,
                     endAngle: endAngle,
                     clockwise: clockwise)
        }
        .stroke(
            LinearGradient(
                colors: [moonColor, sunColor],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: stroke, lineCap: .round)
        )
    }
    
    private func knob(minutes: Binding<Double>,
                      symbol: String,
                      color: Color,
                      radius: CGFloat,
                      centre: CGPoint) -> some View {
        let ang = angle(for: minutes.wrappedValue)
        let rad = CGFloat(ang - 90) * .pi / 180
        let x = centre.x + cos(rad) * radius
        let y = centre.y + sin(rad) * radius
        
        return ZStack {
            Circle()
                .fill(.white)
                .frame(width: knob, height: knob)
                .shadow(color: Color(.black).opacity(0.2), radius: 8, y: 4)
            
            Circle()
                .fill(color)
                .frame(width: knob - 6, height: knob - 6)
            
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
        .position(x: x, y: y)
        .gesture(
            DragGesture()
                .onChanged { g in
                    let v = CGVector(dx: g.location.x - centre.x,
                                     dy: g.location.y - centre.y)
                    
                    var deg = atan2(v.dy, v.dx) * 180 / .pi + 90
                    
                    if deg < 0 {
                        deg += 360
                    }
                    
                    var mins = deg / 360 * 1440
                    mins = (mins / 15).rounded() * 15 // Snap to 15-minute intervals
                    
                    if mins != minutes.wrappedValue {
                        minutes.wrappedValue = mins
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Drag to adjust time")
    }
    
    private var centreTimes: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(sunColor)
                    .font(.system(size: 16))
                Text(timeString(from: wake))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(.label))
            }
            
            HStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .foregroundColor(moonColor)
                    .font(.system(size: 16))
                Text(timeString(from: bed))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(.label))
            }
        }
    }
    
    private func angle(for m: Double) -> Double { m / 1440 * 360 }
    
    private func timeString(from minutes: Double) -> String {
        let total = Int(minutes) % 1440
        let h = total / 60
        let m = total % 60
        let d = Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date())!
        return DateFormatter.localizedString(from: d, dateStyle: .none, timeStyle: .short)
    }
}

private func toMinutes(_ hhmm: String) -> Double {
    let comps = hhmm.split(separator: ":").compactMap { Int($0) }
    guard comps.count == 2 else { return 0 }
    return Double((comps[0] * 60) + comps[1])
}

private func toHHMM(from minutes: Double) -> String {
    let h = Int(minutes) / 60 % 24
    let m = Int(minutes) % 60
    return String(format: "%02d:%02d", h, m)
}

#Preview {
    ScheduleTimes(awakeHours: .constant(AwakeHours(wakeTime: "07:00", sleepTime: "23:00")), themeColor: .blue)
}