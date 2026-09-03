//
//  NotificationBannerView.swift
//  UFree
//

import SwiftUI

/// Foreground banner styled like an iOS notification drop-down.
struct NotificationBannerView: View {
    let notification: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(iconColor.opacity(0.18))
                        .frame(width: 38, height: 38)

                    Image(systemName: notification.inboxIconName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("UFree")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(notification.date.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(notification.senderName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(notification.inboxBannerSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            }
            .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens notifications")
    }

    private var iconColor: Color {
        switch notification.type {
        case .nudge: return .orange
        case .nudgeReply: return .green
        case .friendRequest: return .blue
        case .friendAccepted: return .green
        }
    }
}
