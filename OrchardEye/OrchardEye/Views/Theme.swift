//
//  Theme.swift
//  OrchardEye
//
//  Shared brand design system: the same palette and type treatment as the
//  OrchardEye landing page (../../web). Deep orchard green + ripe amber.
//  New file auto-compiles via the project's file-system-synchronized group.
//

import SwiftUI

// MARK: - Palette

extension Color {
    /// Fresh leaf green: the primary brand green (matches AccentColor).
    static let brandLeaf     = Color(red: 0.204, green: 0.659, blue: 0.325) // #34A853
    /// Deep leaf: for text-on-light and pressed states.
    static let brandLeafDark = Color(red: 0.184, green: 0.490, blue: 0.243) // #2F7D3E
    /// Ripe amber: the "ripeness" accent.
    static let brandRipe     = Color(red: 0.957, green: 0.651, blue: 0.165) // #F4A62A
    /// Dark forest: hero / banner backgrounds.
    static let brandForest   = Color(red: 0.059, green: 0.141, blue: 0.090) // #0F2417
    static let brandForest2  = Color(red: 0.086, green: 0.188, blue: 0.125) // #163020
    /// Warm ink for headings on light backgrounds.
    static let brandInk      = Color(red: 0.078, green: 0.137, blue: 0.102) // #14231A
}

enum Brand {
    /// Leaf → ripe sweep, used on hero marks and highlights.
    static let sweep = LinearGradient(
        colors: [.brandLeaf, .brandRipe],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// Deep forest gradient for banners.
    static let forest = LinearGradient(
        colors: [.brandForest, .brandForest2],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - Eyebrow (small tracked label above a title)

struct Eyebrow: View {
    let text: String
    var color: Color = .brandLeafDark
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

// MARK: - Primary button (solid leaf capsule: matches the site CTA)

struct BrandButtonStyle: ButtonStyle {
    var tint: Color = .brandLeafDark
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(tint.opacity(configuration.isPressed ? 0.82 : 1), in: Capsule())
            .foregroundStyle(.white)
            .shadow(color: tint.opacity(0.35), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Brand mark (apple + sensor "iris": the logo, in SwiftUI)

struct BrandMark: View {
    var size: CGFloat = 96
    var body: some View {
        ZStack {
            Circle().fill(Brand.sweep)
                .overlay(
                    Circle().fill(.white.opacity(0.18))
                        .scaleEffect(0.55).offset(x: -size * 0.12, y: -size * 0.14)
                )
            // stem / leaf
            Capsule()
                .fill(Color.brandLeafDark)
                .frame(width: size * 0.10, height: size * 0.22)
                .rotationEffect(.degrees(20))
                .offset(x: size * 0.10, y: -size * 0.42)
            // sensor iris
            Circle().fill(Color.brandForest).frame(width: size * 0.34)
            Circle().fill(Color.brandRipe).frame(width: size * 0.13)
        }
        .frame(width: size, height: size)
        .shadow(color: .brandLeaf.opacity(0.35), radius: size * 0.14, y: size * 0.08)
        .accessibilityHidden(true)   // decorative logo — skip in VoiceOver
    }
}

#Preview {
    VStack(spacing: 24) {
        BrandMark()
        Eyebrow(text: "On-device orchard scanner")
        Button("Get started") {}.buttonStyle(BrandButtonStyle()).padding(.horizontal)
    }
    .padding()
}
