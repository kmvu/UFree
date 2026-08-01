//
//  PairOnboardingChecklistView.swift
//  UFree
//
//  First-run checklist: invite → mark free → wait for accept.
//

import SwiftUI

struct PairOnboardingChecklistView: View {
    let hasInvited: Bool
    let hasMarkedFree: Bool
    let hasHandshake: Bool
    let onInvite: () -> Void
    let onMarkFree: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Get your first hangout going")
                    .font(.title3.bold())
                Spacer()
                Button("Later", action: onDismiss)
                    .foregroundStyle(.secondary)
            }

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
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
        .padding(.horizontal)
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
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }
}
