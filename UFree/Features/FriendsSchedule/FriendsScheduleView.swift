//
//  FriendsScheduleView.swift
//  UFree
//
//  Created by Khang Vu on 07/01/26.
//

import SwiftUI

public struct FriendsScheduleView: View {
    @ObservedObject var viewModel: FriendsScheduleViewModel
    @State private var selectedDate: Date?

    // Display next 5 days
    private var daysToShow: [Date] {
        let today = Date()
        return (0..<5).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: today) }
    }

    public init(viewModel: FriendsScheduleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Day Selector with Heatmap (Phase 2 - Sprint 6)
                if !viewModel.friendSchedules.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Who's free on...")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(daysToShow, id: \.self) { date in
                                    let freeCount = viewModel.freeFriendCount(for: date, friendsSchedules: viewModel.friendSchedules)
                                    
                                    DayFilterButtonView(
                                        date: date,
                                        isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
                                        freeCount: freeCount,
                                        action: {
                                            selectedDate = date
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Nudge All Button (Phase 3 - Sprint 6)
                if let selectedDate = selectedDate {
                    let freeCount = viewModel.freeFriendCount(for: selectedDate, friendsSchedules: viewModel.friendSchedules)
                    
                    if freeCount > 0 {
                        Button(action: {
                            Task {
                                await viewModel.nudgeAllFree(for: selectedDate)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.wave.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Nudge all \(freeCount) friends")
                                        .fontWeight(.bold)
                                    
                                    Text(selectedDate.formatted(.dateTime.weekday(.abbreviated)))
                                        .font(.caption)
                                        .opacity(0.8)
                                }
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.isNudging ? Color.gray : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                        }
                        .disabled(viewModel.isNudging)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // Show loading state only on first load
                if viewModel.isLoading && viewModel.friendSchedules.isEmpty {
                    ProgressView()
                        .padding()
                } else if viewModel.friendSchedules.isEmpty {
                    ContentUnavailableView(
                        "No Friends Yet",
                        systemImage: "person.2.slash",
                        description: Text("Add friends to see who's available")
                    )
                } else {
                    // List is always in the hierarchy when not loading
                    ForEach(viewModel.friendSchedules) { friendDisplay in
                        FriendScheduleRow(display: friendDisplay, days: daysToShow, viewModel: viewModel)
                    }
                }
            }
            .padding(.vertical)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
            Button("OK") { viewModel.successMessage = nil }
        } message: {
            if let message = viewModel.successMessage {
                Text(message)
            }
        }
        .refreshable {
            await viewModel.loadFriendsSchedules()
        }
    }
}

// MARK: - Friend Schedule Row

private struct FriendScheduleRow: View {
    let display: FriendsScheduleViewModel.FriendScheduleDisplay
    let days: [Date]
    let viewModel: FriendsScheduleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Avatar + Name + Nudge Button
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(String(display.displayName.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.blue)
                    }

                Text(display.displayName)
                    .font(.headline)

                Spacer()

                // Nudge Button
                Button(action: {
                    HapticManager.medium()
                    Task {
                        await viewModel.sendNudge(to: display.id)
                    }
                }) {
                    Image(systemName: "hand.wave.fill")
                        .font(.body)
                        .foregroundColor(.orange)
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }
                .disabled(viewModel.isNudging)
                .opacity(viewModel.isNudging ? 0.5 : 1.0)
            }

            // Horizontal Schedule Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(days, id: \.self) { date in
                        let status = display.status(for: date)
                        FriendStatusPill(date: date, status: status)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Status Pill Component

private struct FriendStatusPill: View {
     let date: Date
     let status: AvailabilityStatus

     init(date: Date, status: AvailabilityStatus) {
         self.date = date
         self.status = status
     }

    private var dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE" // Mon, Tue, etc
        return f
    }()

    var body: some View {
        VStack(spacing: 6) {
            Text(dayFormatter.string(from: date))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Circle()
                .fill(status.displayColor)
                .frame(width: 32, height: 32)
                .overlay {
                    if status == .free {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else if status == .busy {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

            Text(status.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 50)
    }
}

#Preview {
    let mockFriendRepo = MockFriendRepository(
        discoveredUsers: [],
        myFriends: [
            UserProfile(id: "friend1", displayName: "Alice", hashedPhoneNumber: "hash1"),
            UserProfile(id: "friend2", displayName: "Bob", hashedPhoneNumber: "hash2")
        ]
    )

    let mockAvailabilityRepo = MockAvailabilityRepository()
    let mockNotificationRepo = MockNotificationRepository()
    let viewModel = FriendsScheduleViewModel(
        friendRepository: mockFriendRepo,
        availabilityRepository: mockAvailabilityRepo,
        notificationRepository: mockNotificationRepo
    )

    return FriendsScheduleView(viewModel: viewModel)
}
