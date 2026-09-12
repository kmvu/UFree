//
//  PairOnboardingBannerView.swift
//  UFree
//
//  Soft bottom cue for first-hangout onboarding. Tap opens the checklist sheet.
//

import SwiftUI

struct PairOnboardingBannerView: View {
    let title: String
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                        .truncationMode(.tail)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens first hangout checklist")
    }
}

/// Tab-content cue so the system tab bar stays pinned. Pair banner is Who's Free only.
struct OnboardingBottomCue: View {
    @ObservedObject var rootViewModel: RootViewModel
    @ObservedObject var onboardingStore: OnboardingProgressStore
    var showsPairBanner: Bool

    var body: some View {
        let friendCount = rootViewModel.friendsViewModel?.friends.count ?? 0
        if showsPairBanner,
           rootViewModel.showPairOnboardingBanner,
           onboardingStore.shouldShowPairOnboardingBanner(friendCount: friendCount) {
            PairOnboardingBannerView(
                title: onboardingStore.pairOnboardingBannerTitle(friendCount: friendCount),
                subtitle: onboardingStore.pairOnboardingBannerSubtitle(friendCount: friendCount),
                onTap: {
                    rootViewModel.showPairOnboardingSheet = true
                }
            )
        } else if onboardingStore.shouldShowPostConnectCoach {
            PostConnectMissionChipView(
                title: OnboardingProgressStore.postConnectMissionTitle,
                subtitle: rootViewModel.postConnectMissionSubtitle(store: onboardingStore),
                onPrimary: {
                    AnalyticsManager.logMissionChipTapped()
                    rootViewModel.handlePostConnectMissionTap(store: onboardingStore)
                },
                onDismiss: {
                    rootViewModel.dismissPostConnectCoach(store: onboardingStore)
                }
            )
        }
    }
}
