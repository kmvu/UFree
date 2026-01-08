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
                        NotificationRow(note: note)
                            .listRowBackground(note.isRead ? Color.clear : Color.blue.opacity(0.1))
                            .onAppear {
                                if !note.isRead {
                                    viewModel.markRead(note)
                                }
                            }
                    }
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct NotificationRow: View {
    let note: AppNotification
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on type
            ZStack {
                Circle()
                    .fill(note.type == .nudge ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: note.type == .nudge ? "hand.wave.fill" : "person.badge.plus")
                    .foregroundStyle(note.type == .nudge ? .orange : .blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Text(note.date.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    var message: String {
        switch note.type {
        case .friendRequest:
            return "\(note.senderName) sent you a friend request."
        case .nudge:
            return "\(note.senderName) nudged you! 👋"
        }
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
                isRead: true
            )
        ]
    )
    
    NotificationCenterView(viewModel: NotificationViewModel(repository: mockRepo))
}
