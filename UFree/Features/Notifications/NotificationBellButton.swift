//
//  NotificationBellButton.swift
//  UFree
//
//  Created by Khang Vu on 08/01/26.
//

import SwiftUI

struct NotificationBellButton: View {
    @Binding var isPresented: Bool
    @Environment(\.notificationViewModel) private var notificationViewModel

    var body: some View {
        Group {
            if let viewModel = notificationViewModel {
                NotificationBellButtonContent(viewModel: viewModel, isPresented: $isPresented)
            }
        }
    }
}

/// Observes the shared view model directly — optional `@Environment` values do not
/// reliably refresh badge counts when `@Published` state changes.
private struct NotificationBellButtonContent: View {
    @ObservedObject var viewModel: NotificationViewModel
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            viewModel.openNotificationCenter()
            isPresented = true
        } label: {
            ZStack {
                Image(systemName: "bell.fill")
                    .font(.body)

                if viewModel.unreadCount > 0 {
                    Text(badgeLabel)
                        .font(.caption2)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.horizontal, viewModel.unreadCount > 9 ? 5 : 4)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 8, y: -8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.unreadCount)
        }
    }

    private var badgeLabel: String {
        viewModel.unreadCount > 9 ? "9+" : "\(viewModel.unreadCount)"
    }
}

extension EnvironmentValues {
    @Entry var notificationViewModel: NotificationViewModel? = nil
}
