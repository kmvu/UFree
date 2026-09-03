//
//  WhoIsFreeEmptyHeroView.swift
//  UFree
//
//  Intention-first empty state for Who's Free (banner remains the quest coach).
//

import SwiftUI

struct WhoIsFreeEmptyHeroView: View {
    /// 0…3 completed onboarding steps for decorative quest dots.
    var completedSteps: Int = 0
    var showsQuestDots: Bool = false
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

            if showsQuestDots {
                questDots
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    private var questDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < completedSteps ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(min(completedSteps, 3)) of 3 steps done")
    }
}

#Preview {
    WhoIsFreeEmptyHeroView(completedSteps: 1, showsQuestDots: true, onInvite: {})
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
