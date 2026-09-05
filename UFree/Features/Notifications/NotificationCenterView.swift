//
//  NotificationCenterView.swift
//  UFree
//
//  Created by Khang Vu on 08/01/26.
//

import SwiftUI

public struct NotificationCenterView: View {
    @ObservedObject var viewModel: NotificationViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    public init(viewModel: NotificationViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            List {
                if viewModel.notifications.isEmpty {
                    ContentUnavailableView(
                        "All Caught Up",
                        systemImage: "bell.slash",
                        description: Text("No new notifications.")
                    )
                } else {
                    ForEach(viewModel.notifications) { note in
                        NotificationRow(note: note, viewModel: viewModel)
                            .listRowBackground(rowBackground(for: note))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.clearNotification(note)
                                } label: {
                                    Label("Clear", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if note.isRead {
                                    Button {
                                        viewModel.markUnread(note)
                                    } label: {
                                        Label("Unread", systemImage: "envelope.badge")
                                    }
                                    .tint(.blue)
                                } else {
                                    Button {
                                        viewModel.markRead(note)
                                    } label: {
                                        Label("Read", systemImage: "envelope.open")
                                    }
                                    .tint(.gray)
                                }
                            }
                            .contextMenu {
                                if note.isRead {
                                    Button("Mark as Unread") {
                                        viewModel.markUnread(note)
                                    }
                                } else {
                                    Button("Mark as Read") {
                                        viewModel.markRead(note)
                                    }
                                }
                                Button("Clear", role: .destructive) {
                                    viewModel.clearNotification(note)
                                }
                            }
                            .onAppear {
                                if !note.isRead && note.type == .nudgeReply {
                                    viewModel.markRead(note)
                                    if let response = note.nudgeResponse {
                                        AnalyticsManager.logNudgeReplyReceived(response: response)
                                    }
                                }
                            }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .adaptiveContentWidth(640)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(horizontalSizeClass == .regular ? .large : .inline)
            .accessibilityIdentifier("notifications.root")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.unreadCount > 0 {
                        Button("Mark All Read") {
                            viewModel.markAllRead()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let error = viewModel.errorMessage { Text(error) }
            }
        }
    }

    private func rowBackground(for note: AppNotification) -> Color {
        if note.type == .friendAccepted
            || (note.type == .friendRequest && !viewModel.isFriendRequestActionable(note)) {
            return Color.green.opacity(0.08)
        }
        return note.isRead ? Color.clear : Color.blue.opacity(0.1)
    }
}

struct NotificationRow: View {
    let note: AppNotification
    @ObservedObject var viewModel: NotificationViewModel

    private var isRowProcessing: Bool {
        viewModel.isProcessingNotification(note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: iconName)
                        .foregroundStyle(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.inboxMessage)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Text(note.date.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }

            if viewModel.isFriendRequestActionable(note) {
                Button(action: {
                    Task { await viewModel.acceptFriendRequest(from: note) }
                }) {
                    if isRowProcessing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Accept")
                    }
                }
                .ufreeCompactButton(tint: .green)
                .disabled(viewModel.hasActiveNotificationAction)
                .accessibilityIdentifier("notifications.accept")
            } else if note.type == .friendRequest || note.type == .friendAccepted {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }

            if note.type == .nudge && !note.hasResponded {
                HStack(spacing: 8) {
                    ForEach(AppNotification.NudgeResponse.allCases, id: \.rawValue) { response in
                        Button(response.displayLabel) {
                            Task { await viewModel.replyToNudge(note, response: response) }
                        }
                        .ufreeCompactButton(
                            prominent: response == .imIn,
                            tint: response == .imIn ? .green : (response == .busy ? .red : .orange)
                        )
                        .disabled(viewModel.hasActiveNotificationAction)
                        .accessibilityIdentifier("notifications.reply.\(response.rawValue)")
                    }
                }
            }

            if note.type == .nudge, let responded = note.nudgeResponse,
               let response = AppNotification.NudgeResponse(rawValue: responded) {
                Text("You replied: \(response.displayLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch note.type {
        case .nudge: return "hand.wave.fill"
        case .nudgeReply: return "checkmark.bubble.fill"
        case .friendRequest: return "person.badge.plus"
        case .friendAccepted: return "person.2.fill"
        }
    }

    private var iconColor: Color {
        switch note.type {
        case .nudge: return .orange
        case .nudgeReply: return .green
        case .friendRequest: return .blue
        case .friendAccepted: return .green
        }
    }

    private var iconBackground: Color {
        iconColor.opacity(0.2)
    }

    var message: String {
        note.inboxMessage
    }
}

#Preview {
    let mockRepo = MockNotificationRepository(
        notifications: [
            AppNotification(
                recipientId: "user1",
                senderId: "sender1",
                senderName: "Alice",
                type: .friendRequest,
                date: Date(),
                isRead: false
            ),
            AppNotification(
                recipientId: "user1",
                senderId: "sender2",
                senderName: "Bob",
                type: .nudge,
                date: Date().addingTimeInterval(-3600),
                isRead: true,
                targetDateString: AppNotification.dateString(from: Date())
            )
        ]
    )
    
    NotificationCenterView(viewModel: NotificationViewModel(repository: mockRepo))
}
