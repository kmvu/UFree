//
//  UFreeButtons.swift
//  UFree
//
//  Roomy, consistent product CTAs (primary / secondary / compact).
//

import SwiftUI

/// Accent-filled primary action — full-width friendly, comfortable padding.
struct UFreePrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(UFreeType.ctaLabel)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? tint : Color.gray.opacity(0.35))
            )
            .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1)
            .opacity(configuration.isPressed && isEnabled ? 0.88 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Subtle filled / stroked secondary action with the same breathing room as primary.
struct UFreeSecondaryButtonStyle: ButtonStyle {
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(UFreeType.ctaLabel)
            .foregroundStyle(tint)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(tint.opacity(0.25), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Inline row actions — still padded; not system `.controlSize(.small)`.
struct UFreeCompactButtonStyle: ButtonStyle {
    var prominent: Bool = true
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(UFreeType.compactCTALabel)
            .foregroundStyle(prominent ? Color.white : tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(prominent ? tint : tint.opacity(0.12))
            )
            .overlay {
                if !prominent {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.25), lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func ufreePrimaryButton(isEnabled: Bool = true, tint: Color = .accentColor) -> some View {
        buttonStyle(UFreePrimaryButtonStyle(isEnabled: isEnabled, tint: tint))
    }

    func ufreeSecondaryButton(tint: Color = .accentColor) -> some View {
        buttonStyle(UFreeSecondaryButtonStyle(tint: tint))
    }

    func ufreeCompactButton(prominent: Bool = true, tint: Color = .accentColor) -> some View {
        buttonStyle(UFreeCompactButtonStyle(prominent: prominent, tint: tint))
    }
}
