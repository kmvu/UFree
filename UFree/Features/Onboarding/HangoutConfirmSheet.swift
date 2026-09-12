//
//  HangoutConfirmSheet.swift
//  UFree
//
//  One-tap “did you hang out?” after an I’m-in day has passed.
//

import SwiftUI

struct HangoutConfirmSheet: View {
    let friendName: String
    let weekdayLabel: String?
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.2")
                .font(.system(size: 44))
                .foregroundStyle(.green)

            Text(title)
                .font(UFreeType.heroTitle)
                .multilineTextAlignment(.center)

            Text("One tap so you both remember it. No pressure if it didn’t happen.")
                .font(UFreeType.heroBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                HapticManager.success()
                onConfirm()
            }) {
                Text("Yes, we hung out")
                    .frame(maxWidth: .infinity)
            }
            .ufreePrimaryButton()

            Button("Not this time", action: onDismiss)
                .font(UFreeType.ctaLabel)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
        }
        .padding(24)
        .accessibilityIdentifier("hangout.confirm.sheet")
    }

    private var title: String {
        if let weekdayLabel, !weekdayLabel.isEmpty {
            return "Did you hang out with \(friendName) on \(weekdayLabel)?"
        }
        return "Did you hang out with \(friendName)?"
    }
}
