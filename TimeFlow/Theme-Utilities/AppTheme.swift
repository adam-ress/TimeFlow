//
//  AppTheme.swift
//  TimeFlow
//
//  Created by Adam Ress on 7/1/25.
//

import SwiftUI

// MARK: - App Theme
struct AppTheme {
    
    // MARK: - Main App Colors
    struct Colors {
        // Primary brand colors (same for both modes)
        static let primary = Color(#colorLiteral(red: 0.4258667827, green: 0.5589191914, blue: 0.9503996968, alpha: 1))          // Main brand blue
        static let accent = Color(#colorLiteral(red: 0.6282500625, green: 0.6713039875, blue: 0.9483621716, alpha: 1))  // Purple accent
        static let secondary = Color(#colorLiteral(red: 0.25, green: 0.29, blue: 0.42, alpha: 1))       // Muted navy
       
        // Background colors - color scheme aware
        static func background(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.black : Color(red: 0.98, green: 0.98, blue: 0.99)  // Light: off-white
        }
        
        static func cardBackground(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark 
                ? Color(#colorLiteral(red: 0.13, green: 0.13, blue: 0.15, alpha: 1))  // Dark card bg
                : Color.white  // Light: white
        }
        
        static let cardStroke = Color(#colorLiteral(red: 1, green: 0, blue: 0, alpha: 1))      // Card border
        
        // Text colors - color scheme aware
        static func textPrimary(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.white : Color(red: 0.1, green: 0.1, blue: 0.12)  // Light: near-black
        }
        
        static func textSecondary(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark 
                ? Color.white.opacity(0.9) 
                : Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.8)  // Light: dark with opacity
        }
        
        static func textTertiary(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark 
                ? Color.white.opacity(0.7) 
                : Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.6)  // Light: dark with opacity
        }
        
        static func textQuaternary(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark 
                ? Color.white.opacity(0.5) 
                : Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.5)  // Light: dark with opacity
        }
        
        // UI element colors - color scheme aware
        static func separator(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark 
                ? Color.white.opacity(0.07) 
                : Color.black.opacity(0.1)  // Light: dark with opacity
        }
        
        static func overlay(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark 
                ? Color.white.opacity(0.16) 
                : Color.black.opacity(0.08)  // Light: dark with opacity
        }
        
        static func disabled(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark 
                ? Color.white.opacity(0.15) 
                : Color.black.opacity(0.1)  // Light: dark with opacity
        }
        
        static func disabledText(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark 
                ? Color.white.opacity(0.5) 
                : Color.black.opacity(0.4)  // Light: dark with opacity
        }
        
        // Backward compatibility - default to dark mode
        static var background: Color { background(for: .dark) }
        static var cardBackground: Color { cardBackground(for: .dark) }
        static var textPrimary: Color { textPrimary(for: .dark) }
        static var textSecondary: Color { textSecondary(for: .dark) }
        static var textTertiary: Color { textTertiary(for: .dark) }
        static var textQuaternary: Color { textQuaternary(for: .dark) }
        static var separator: Color { separator(for: .dark) }
        static var overlay: Color { overlay(for: .dark) }
        static var disabled: Color { disabled(for: .dark) }
        static var disabledText: Color { disabledText(for: .dark) }
    }
    
    // MARK: - Age Group Colors
    struct AgeGroupColors {
        static let middleSchool = Color(#colorLiteral(red: 0.8331212401, green: 0.2112448812, blue: 0.09534264356, alpha: 1))
        static let highSchool = Color(#colorLiteral(red: 0, green: 0.664678514, blue: 0.580894351, alpha: 1))
        static let college = Color(#colorLiteral(red: 0.4225499034, green: 0.2747703493, blue: 0.7697501779, alpha: 1))
        static let youngProfessional = Color(#colorLiteral(red: 0.8549019694, green: 0.250980407, blue: 0.4784313738, alpha: 1))
    }
    
    // MARK: - Event Type Colors
    struct EventColors {
        static let school = AgeGroupColors.highSchool
        static let collegeClass = AgeGroupColors.college
        static let work = Color(#colorLiteral(red: 0.98, green: 0.62, blue: 0.29, alpha: 1))            // Warm orange
        static let goal = Color(#colorLiteral(red: 0.30, green: 0.82, blue: 0.45, alpha: 1))            // Success green
        static let recurringCommitment = Color(#colorLiteral(red: 0.35, green: 0.78, blue: 0.98, alpha: 1))  // Light blue
        static let assignment = Color(#colorLiteral(red: 0.98, green: 0.39, blue: 0.40, alpha: 1))      // Coral red
        static let testStudy = Color(#colorLiteral(red: 0.98, green: 0.82, blue: 0.29, alpha: 1))       // Warning yellow
        static let breakTime = Color(#colorLiteral(red: 0.60, green: 0.60, blue: 0.60, alpha: 1))       // Neutral gray
        static let leisure = Color(#colorLiteral(red: 0.98, green: 0.51, blue: 0.85, alpha: 1))         // Pink
        static let other = Color(#colorLiteral(red: 0.70, green: 0.70, blue: 0.70, alpha: 1))           // Light gray
    }
    
    // MARK: - Activity Colors (for goals, activities, etc.)
    struct ActivityColors {
        static let red = Color(#colorLiteral(red: 0.98, green: 0.39, blue: 0.40, alpha: 1))
        static let orange = Color(#colorLiteral(red: 0.98, green: 0.62, blue: 0.29, alpha: 1))
        static let yellow = Color(#colorLiteral(red: 0.98, green: 0.82, blue: 0.29, alpha: 1))
        static let green = Color(#colorLiteral(red: 0.30, green: 0.82, blue: 0.45, alpha: 1))
        static let mint = Color(#colorLiteral(red: 0.40, green: 0.90, blue: 0.80, alpha: 1))
        static let teal = Color(#colorLiteral(red: 0.29, green: 0.78, blue: 0.82, alpha: 1))
        static let cyan = Color(#colorLiteral(red: 0.35, green: 0.78, blue: 0.98, alpha: 1))
        static let blue = Colors.primary
        static let indigo = Color(#colorLiteral(red: 0.35, green: 0.45, blue: 0.90, alpha: 1))
        static let purple = Colors.accent
        static let pink = Color(#colorLiteral(red: 0.98, green: 0.51, blue: 0.85, alpha: 1))
        static let maroon = Color(#colorLiteral(red: 0.68, green: 0.29, blue: 0.32, alpha: 1))
        
        // Color palette function (maintains compatibility with existing code)
        static func palette(_ token: String) -> Color {
            switch token.lowercased() {
            case "red": return red
            case "orange": return orange
            case "yellow": return yellow
            case "green": return green
            case "mint": return mint
            case "teal": return teal
            case "cyan": return cyan
            case "blue": return blue
            case "indigo": return indigo
            case "purple": return purple
            case "pink": return pink
            case "maroon": return maroon
            case "middleschool": return AgeGroupColors.middleSchool
            case "highschool": return AgeGroupColors.highSchool
            case "college": return AgeGroupColors.college
            case "youngpro": return AgeGroupColors.youngProfessional
            case "accent": return Colors.accent
            default: return Colors.primary
            }
        }
    }
    
    // MARK: - Background Gradients
    struct Gradients {
        static func backgroundGradient(for hour: Int, colorScheme: ColorScheme = .dark) -> LinearGradient {
            let colors: [Color]
            
            if colorScheme == .light {
                // Light mode gradients - softer, lighter tones
                switch hour {
                case 0..<12:                // Morning - soft and optimistic
                    colors = [
                        Color(red: 0.99, green: 0.95, blue: 0.92),   // soft warm white
                        Color(red: 0.98, green: 0.90, blue: 0.85)   // light peach
                    ]
                case 12..<18:               // Mid-day - neutral, professional
                    colors = [
                        Color(red: 0.97, green: 0.97, blue: 0.98),   // cool light gray
                        Color(red: 0.95, green: 0.96, blue: 0.98)    // very light blue-gray
                    ]
                default:                    // Evening & night - deep and moody
                    colors = [
                        Color(red: 0.94, green: 0.95, blue: 0.97),   // light blue-gray
                        Color(red: 0.92, green: 0.93, blue: 0.96)   // slightly darker blue-gray
                    ]
                }
            } else {
                // Dark mode gradients (original)
                switch hour {
                case 0..<12:                // Morning - soft and optimistic
                    colors = [
                        Color(red: 0.96, green: 0.65, blue: 0.66),   // soft coral-rose
                        Color(red: 0.80, green: 0.37, blue: 0.53)    // muted cherry-pink
                    ]
                case 12..<18:               // Mid-day - neutral, professional
                    colors = [
                        Color(red: 0.25, green: 0.29, blue: 0.42),   // muted navy
                        Color(red: 0.12, green: 0.15, blue: 0.26)    // charcoal
                    ]
                default:                    // Evening & night - deep and moody
                    colors = [
                        Color(red: 0.08, green: 0.14, blue: 0.30),   // deep sapphire
                        Color(red: 0.02, green: 0.05, blue: 0.12)    // near-black navy
                    ]
                }
            }
            return LinearGradient(gradient: Gradient(colors: colors), startPoint: .top, endPoint: .bottom)
        }
        
        static func cardGradient(for colorScheme: ColorScheme = .dark) -> LinearGradient {
            let cardBg = Colors.cardBackground(for: colorScheme)
            return LinearGradient(
                colors: [cardBg, cardBg.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        
        // Backward compatibility
        static func backgroundGradient(for hour: Int) -> LinearGradient {
            backgroundGradient(for: hour, colorScheme: .dark)
        }
        
        static var cardGradient: LinearGradient {
            cardGradient(for: .dark)
        }
    }
    
    // MARK: - Typography (preserving current sizes and weights)
    struct Typography {
        // Headers
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.bold)
        static let title3 = Font.title3.weight(.semibold)
        
        // Body text
        static let headline = Font.headline
        static let subheadline = Font.subheadline
        static let subheadlineSemibold = Font.subheadline.weight(.semibold)
        static let body = Font.body
        static let bodySemibold = Font.body.weight(.semibold)
        static let callout = Font.callout
        
        // Small text
        static let caption = Font.caption
        static let caption2 = Font.caption2
        static let footnote = Font.footnote
        
        // Custom styles matching current usage
        static let buttonLabel = Font.body.weight(.semibold)
        static let cardTitle = Font.headline
        static let progressText = Font.subheadline.weight(.semibold)
        static let timeLabel = Font.caption2.weight(.semibold)
    }
    
    // MARK: - Spacing & Layout
    struct Layout {
        static let cornerRadius: CGFloat = 20
        static let smallCornerRadius: CGFloat = 16
        static let largeCornerRadius: CGFloat = 30
        
        static let shadowRadius: CGFloat = 6
        static let shadowOffset: CGFloat = 3
        
        static let standardPadding: CGFloat = 16
        static let largePadding: CGFloat = 24
        static let smallPadding: CGFloat = 8
    }
    
    // MARK: - Shadow Styles
    struct Shadows {
        static func card(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark 
                ? Color.black.opacity(0.4) 
                : Color.black.opacity(0.1)  // Light: subtle shadow
        }
        
        static func button(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark 
                ? Color.black.opacity(0.35) 
                : Color.black.opacity(0.08)  // Light: subtle shadow
        }
        
        static func overlay(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark 
                ? Color.black.opacity(0.55) 
                : Color.black.opacity(0.2)  // Light: lighter overlay
        }
        
        static func icon(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark 
                ? Color.white.opacity(0.18) 
                : Color.black.opacity(0.15)  // Light: dark icon shadow
        }
        
        // Backward compatibility
        static var card: Color { card(for: .dark) }
        static var button: Color { button(for: .dark) }
        static var overlay: Color { overlay(for: .dark) }
        static var icon: Color { icon(for: .dark) }
    }
}

// MARK: - Convenience Extensions
extension Color {
    // Main theme colors
    static let theme = AppTheme.Colors.self
    
    // Quick access to common theme colors
    static let themeAccent = AppTheme.Colors.accent
    static let themePrimary = AppTheme.Colors.primary
    static let themeSecondary = AppTheme.Colors.secondary
    static let themeCardBackground = AppTheme.Colors.cardBackground
    static let themeCardStroke = AppTheme.Colors.cardStroke
    
    // Activity colors with improved naming
    static func activityColor(_ name: String) -> Color {
        return AppTheme.ActivityColors.palette(name)
    }
    
    // Age group colors
    static func ageGroupColor(for ageGroup: AgeGroup) -> Color {
        switch ageGroup {
        case .middleSchool: return AppTheme.AgeGroupColors.middleSchool
        case .highSchool: return AppTheme.AgeGroupColors.highSchool
        case .college: return AppTheme.AgeGroupColors.college
        case .youngProfessional: return AppTheme.AgeGroupColors.youngProfessional
        }
    }
}

// MARK: - Font Extensions
extension Font {
    static let theme = AppTheme.Typography.self
}

// MARK: - View Modifier Extensions
extension View {
    func themeCard(colorScheme: ColorScheme = .dark) -> some View {
        self
            .background(AppTheme.Colors.cardBackground(for: colorScheme))
            .cornerRadius(AppTheme.Layout.cornerRadius)
            .shadow(color: AppTheme.Shadows.card(for: colorScheme), radius: AppTheme.Layout.shadowRadius, y: AppTheme.Layout.shadowOffset)
    }
    
    func themeCardWithStroke(selected: Bool = false, strokeColor: Color = AppTheme.Colors.cardStroke, colorScheme: ColorScheme = .dark) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius)
                    .fill(AppTheme.Colors.cardBackground(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius)
                            .stroke(selected ? strokeColor : Color.clear, lineWidth: 3)
                    )
            )
            .shadow(color: AppTheme.Shadows.card(for: colorScheme), radius: AppTheme.Layout.shadowRadius, y: AppTheme.Layout.shadowOffset)
    }
    
    func themeButton(enabled: Bool = true, color: Color = AppTheme.Colors.accent, colorScheme: ColorScheme = .dark) -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding()
            .background(enabled ? color : AppTheme.Colors.disabled(for: colorScheme))
            .foregroundColor(enabled ? AppTheme.Colors.textPrimary(for: colorScheme) : AppTheme.Colors.disabledText(for: colorScheme))
            .cornerRadius(AppTheme.Layout.smallCornerRadius)
    }
}

// MARK: - Theme Helper for Views
extension View {
    /// Provides easy access to theme colors using the current color scheme from environment
    func themeColors(_ colorScheme: ColorScheme) -> ThemeColorProvider {
        ThemeColorProvider(colorScheme: colorScheme)
    }
}

struct ThemeColorProvider {
    let colorScheme: ColorScheme
    
    var background: Color { AppTheme.Colors.background(for: colorScheme) }
    var cardBackground: Color { AppTheme.Colors.cardBackground(for: colorScheme) }
    var textPrimary: Color { AppTheme.Colors.textPrimary(for: colorScheme) }
    var textSecondary: Color { AppTheme.Colors.textSecondary(for: colorScheme) }
    var textTertiary: Color { AppTheme.Colors.textTertiary(for: colorScheme) }
    var textQuaternary: Color { AppTheme.Colors.textQuaternary(for: colorScheme) }
    var separator: Color { AppTheme.Colors.separator(for: colorScheme) }
    var overlay: Color { AppTheme.Colors.overlay(for: colorScheme) }
    var disabled: Color { AppTheme.Colors.disabled(for: colorScheme) }
    var disabledText: Color { AppTheme.Colors.disabledText(for: colorScheme) }
    var cardShadow: Color { AppTheme.Shadows.card(for: colorScheme) }
    var buttonShadow: Color { AppTheme.Shadows.button(for: colorScheme) }
    var overlayShadow: Color { AppTheme.Shadows.overlay(for: colorScheme) }
    var iconShadow: Color { AppTheme.Shadows.icon(for: colorScheme) }
}
