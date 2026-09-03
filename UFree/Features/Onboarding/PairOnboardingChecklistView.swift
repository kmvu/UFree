//
//  PairOnboardingChecklistView.swift
//  UFree
//
//  First-run checklist sheet: invite → mark free → wait for accept.
//

import SwiftUI

struct PairOnboardingChecklistView: View {
    let hasInvited: Bool
    let hasMarkedFree: Bool
    let hasHandshake: Bool
    let onInvite: () -> Void
    let onMarkFree: () -> Void
    let onNotNow: () -> Void
    let onDontShowAgain: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Invite a friend, mark when you're free, then pick a night together.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                checklistRow(
                    done: hasInvited,
                    title: "Invite 1 friend",
                    subtitle: "Share your link or show your QR",
                    actionTitle: "Invite",
                    action: onInvite
                )

                checklistRow(
                    done: hasMarkedFree,
                    title: "Mark days you're free",
                    subtitle: "Start with this weekend",
                    actionTitle: "Mark free",
                    action: onMarkFree
                )

                checklistRow(
                    done: hasHandshake,
                    title: "Wait for them to accept",
                    subtitle: "You'll land on Who's Free together",
                    actionTitle: nil,
                    action: nil
                )

                Spacer(minLength: 0)

                Button("Don't show again", action: onDontShowAgain)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
            .navigationTitle("Get your first hangout going")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now", action: onNotNow)
                }
            }
        }
    }

    @ViewBuilder
    private func checklistRow(
        done: Bool,
        title: String,
        subtitle: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : Color.secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .strikethrough(done)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !done, let actionTitle, let action {
                Button(actionTitle, action: action)
                    .ufreeCompactButton()
            }
        }
    }
}
