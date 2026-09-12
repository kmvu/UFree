//
//  WhoIsFreeEmptyHeroView.swift
//  UFree
//
//  Intention-first empty state for Who's Free (banner remains the quest coach).
//

import SwiftUI

struct WhoIsFreeEmptyHeroView: View {
    let onInvite: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 112, height: 112)

                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.bounce, options: .repeating)
            }
            .padding(.top, 12)

            VStack(spacing: 10) {
                Text("Free nights, with people you trust")
                    .font(UFreeType.heroTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text("Invite a friend, mark when you’re free, then pick a night together.")
                    .font(UFreeType.heroBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Button(action: {
                HapticManager.medium()
                onInvite()
            }) {
                HStack(spacing: 10) {
                    Text("Invite a friend")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }
            .ufreePrimaryButton()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    WhoIsFreeEmptyHeroView(onInvite: {})
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
