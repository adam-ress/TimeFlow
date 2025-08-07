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
        // Primary brand colors
        static let primary = Color(#colorLiteral(red: 0.4258667827, green: 0.5589191914, blue: 0.9503996968, alpha: 1))          // Main brand blue
        static let accent = Color(#colorLiteral(red: 0.6282500625, green: 0.6713039875, blue: 0.9483621716, alpha: 1))  // Purple accent
        static let secondary = Color(#colorLiteral(red: 0.25, green: 0.29, blue: 0.42, alpha: 1))       // Muted navy
       
        // Background colors
        static let background = Color.black
        static let cardBackground = Color(#colorLiteral(red: 0.13, green: 0.13, blue: 0.15, alpha: 1))  // Dark card bg
        static let cardStroke = Color(#colorLiteral(red: 1, green: 0, blue: 0, alpha: 1))      // Card border
        
        // Text colors
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.9)
        static let textTertiary = Color.white.opacity(0.7)
        static let textQuaternary = Color.white.opacity(0.5)
        
        // UI element colors
        static let separator = Color.white.opacity(0.07)
        static let overlay = Color.white.opacity(0.16)
        static let disabled = Color.white.opacity(0.15)
        static let disabledText = Color.white.opacity(0.5)
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
        static func backgroundGradient(for hour: Int) -> LinearGradient {
            let colors: [Color]
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
            return LinearGradient(gradient: Gradient(colors: colors), startPoint: .top, endPoint: .bottom)
        }
        
        static let cardGradient = LinearGradient(
            colors: [Colors.cardBackground, Colors.cardBackground.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
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
        static let card = Color.black.opacity(0.4)
        static let button = Color.black.opacity(0.35)
        static let overlay = Color.black.opacity(0.55)
        static let icon = Color.white.opacity(0.18)
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
    func themeCard() -> some View {
        self
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(AppTheme.Layout.cornerRadius)
            .shadow(color: AppTheme.Shadows.card, radius: AppTheme.Layout.shadowRadius, y: AppTheme.Layout.shadowOffset)
    }
    
    func themeCardWithStroke(selected: Bool = false, strokeColor: Color = AppTheme.Colors.cardStroke) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius)
                    .fill(AppTheme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius)
                            .stroke(selected ? strokeColor : Color.clear, lineWidth: 3)
                    )
            )
            .shadow(color: AppTheme.Shadows.card, radius: AppTheme.Layout.shadowRadius, y: AppTheme.Layout.shadowOffset)
    }
    
    func themeButton(enabled: Bool = true, color: Color = AppTheme.Colors.accent) -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding()
            .background(enabled ? color : AppTheme.Colors.disabled)
            .foregroundColor(enabled ? AppTheme.Colors.textPrimary : AppTheme.Colors.disabledText)
            .cornerRadius(AppTheme.Layout.smallCornerRadius)
    }
}
