//
//  CelebrationToastCard.swift
//  UFree
//
//  Short spring card for first-connection and hang milestones.
//

import SwiftUI

struct CelebrationToastCard: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, value: message)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .accessibilityIdentifier("celebration.toast")
        .accessibilityAddTraits(.isStaticText)
    }
}
