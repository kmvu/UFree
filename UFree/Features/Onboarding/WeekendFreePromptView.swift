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
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("Friends can only find you when you set free days. Tap once to free up Saturday and Sunday.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                HapticManager.success()
                onMarkWeekendFree()
            }) {
                Text("I'm free Sat & Sun")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button("Not now", action: onDismiss)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}
