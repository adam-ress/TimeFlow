//
//  SubscriptionView.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/30/25.
//

import SwiftUI

struct SubscriptionView: View {
    let discountMonthly: Double = 0
    let discountYearly:  Double = 0
    var onContinue: (() -> Void)?
    
    // MARK: – Plan definition
    enum Plan: CaseIterable, Identifiable {
        case monthly, yearly
        var id: Self { self }
        
        var title: String   { self == .monthly ? "Monthly" : "Yearly" }
        var base:  Double   { self == .monthly ? 12.99   : 99.99   }
        var unit:  String   { self == .monthly ? "/mo"   : "/yr"   }
        var sub:   String   { self == .monthly ? "Billed Monthly" : "Free 1 Week Trial" }
        var star:  Bool     { self == .yearly }   // highlight annual
    }
    
    // MARK: – Environment & state
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Plan = .yearly
    @State private var isPurchasing = false
    
    // MARK: – Body
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                
                // Header controls
                headerBar
                
                // Placeholder hero image—swap with your own
                Rectangle()
                    .fill(Color.white)
                    .aspectRatio(1.05, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                // Branding
                branding
                
                Text("UNLOCK ALL FEATURES")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
                
                features
                
                // Pricing options
                HStack(spacing: 12) {
                    ForEach(Plan.allCases) { plan in
                        pricingCard(for: plan,
                                    discount: plan == .monthly ? discountMonthly : discountYearly)
                    }
                }
                
                // CTA
                Button(action: subscribe) {
                    Text(isPurchasing ? "Processing…" : "Start Your Trial")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.pink, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isPurchasing)
                
                // Maybe Later button for onboarding
                if onContinue != nil {
                    Button("Maybe Later") {
                        onContinue?()
                    }
                    .foregroundColor(.secondary)
                }
                
                Text("Cancel anytime • Terms • Privacy")
                    .font(.footnote).foregroundColor(.secondary)
            }
            .padding()
        }
    }
    
    // MARK: – Sub-Components
    private var headerBar: some View {
        HStack {
            Button { 
                if let onContinue = onContinue {
                    onContinue() // If in onboarding flow, continue
                } else {
                    dismiss() // If standalone, dismiss
                }
            } label: {
                Image(systemName: "xmark")
                    .padding(8).background(.ultraThinMaterial, in: Circle())
            }
            Spacer()
            Button("Restore Purchase") { /* restore */ }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .foregroundStyle(.white)
    }
    
    private var branding: some View {
        HStack(spacing: 6) {
            Text("TimeFlow").font(.title.weight(.bold))
            Text("PRO")
                .font(.caption2.weight(.bold))
                .padding(.vertical, 2).padding(.horizontal, 6)
                .background(Color.white.opacity(0.2), in: Capsule())
        }
        .foregroundColor(.white)
    }
    
    private var features: some View {
        HStack(spacing: 32) {
            feature(icon: "calendar.badge.clock", label: "Smart\nSchedules")
            feature(icon: "sparkles",            label: "No\nWatermark")
            feature(icon: "arrow.triangle.2.circlepath", label: "Extended\nSync")
        }
    }
    
    private func feature(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title2)
            Text(label).multilineTextAlignment(.center).font(.caption2)
        }
        .foregroundColor(.white)
    }
    
    // MARK: – Pricing Card
    @ViewBuilder
    private func pricingCard(for plan: Plan, discount: Double) -> some View {
        let original  = plan.base
        let final     = original * (1 - discount / 100)
        let hasDeal   = discount > 0
        let strokeClr = selected == plan ? Color.pink : Color.secondary.opacity(0.4)
        
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.title).font(.caption.weight(.semibold))
            
            if hasDeal {
                Text(original, format: .currency(code: "USD"))
                    .strikethrough().foregroundColor(.secondary)
                Text(final, format: .currency(code: "USD"))
                    .font(.title3.weight(.bold))
            } else {
                Text(original, format: .currency(code: "USD"))
                    .font(.title3.weight(.bold))
            }
            
            Text(plan.unit).font(.caption2).foregroundColor(.secondary)
            Text(plan.sub).font(.caption2).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.13, green: 0.13, blue: 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(strokeClr, lineWidth: selected == plan ? 2 : 1)
        )
        .overlay(alignment: .topTrailing) {
            Group {
                if plan.star { Image(systemName: "sparkles").foregroundColor(.pink) }
                if hasDeal   { discountBadge(discount) }
            }
            .offset(x: -6, y: -6)
        }
        .onTapGesture { selected = plan }
        .foregroundColor(.white)
    }
    
    // Neumorphic/glass discount badge
    private func discountBadge(_ percent: Double) -> some View {
        Text("\(Int(percent))% OFF")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(
                LinearGradient(colors: [Color.pink.opacity(0.9), Color.pink.opacity(0.6)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(0.85)
            , in: Capsule())
    }
    
    // MARK: – Purchase simulation
    private func subscribe() {
        guard !isPurchasing else { return }
        isPurchasing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { 
            isPurchasing = false
            onContinue?() // Continue after successful purchase
        }
    }
}