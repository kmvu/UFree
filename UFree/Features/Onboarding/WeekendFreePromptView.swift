//
//  WeekendFreePromptView.swift
//  UFree
//
//  One-time post-handshake CTA to mark Sat/Sun free.
//

import SwiftUI

struct WeekendFreePromptView: View {
    let onMarkWeekendFree: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("Mark this weekend free?")
                .font(UFreeType.heroTitle)
                .multilineTextAlignment(.center)

            Text("Friends can only find you when you set free days. Tap once to free up Saturday and Sunday.")
                .font(UFreeType.heroBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                HapticManager.success()
                onMarkWeekendFree()
            }) {
                Text("I'm free Sat & Sun")
                    .frame(maxWidth: .infinity)
            }
            .ufreePrimaryButton()

            Button("Not now", action: onDismiss)
                .font(UFreeType.ctaLabel)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
        }
        .padding(24)
    }
}
