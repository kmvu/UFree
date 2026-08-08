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
                        NotificationRow(note: note, viewModel: viewModel)
                            .listRowBackground(note.isRead ? Color.clear : Color.blue.opacity(0.1))
                            .onAppear {
                                if !note.isRead && note.type != .nudge {
                                    viewModel.markRead(note)
                                } else if !note.isRead && note.type == .nudgeReply {
                                    viewModel.markRead(note)
                                    if let response = note.nudgeResponse {
                                        AnalyticsManager.logNudgeReplyReceived(response: response)
                                    }
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
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let error = viewModel.errorMessage { Text(error) }
            }
        }
    }
}

struct NotificationRow: View {
    let note: AppNotification
    @ObservedObject var viewModel: NotificationViewModel
    
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
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Text(note.date.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }

            if note.type == .friendRequest {
                Button("Accept") {
                    Task { await viewModel.acceptFriendRequest(from: note) }
                }
                .ufreeCompactButton(tint: .green)
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
                        .disabled(viewModel.isProcessing)
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
        let day = note.targetWeekdayLabel
        switch note.type {
        case .friendRequest:
            return "\(note.senderName) sent you a friend request."
        case .friendAccepted:
            return "\(note.senderName) accepted — you're connected!"
        case .nudge:
            if let day {
                return "\(note.senderName) asked if you're free \(day)"
            }
            return "\(note.senderName) nudged you! 👋"
        case .nudgeReply:
            let response = note.nudgeResponse.flatMap { AppNotification.NudgeResponse(rawValue: $0) }
            let verb: String
            switch response {
            case .imIn: verb = "is in"
            case .maybe: verb = "said maybe"
            case .busy: verb = "is busy"
            case .none: verb = "replied"
            }
            if let day {
                return "\(note.senderName) \(verb) for \(day)"
            }
            return "\(note.senderName) \(verb)"
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
                isRead: true,
                targetDateString: AppNotification.dateString(from: Date())
            )
        ]
    )
    
    NotificationCenterView(viewModel: NotificationViewModel(repository: mockRepo))
}
