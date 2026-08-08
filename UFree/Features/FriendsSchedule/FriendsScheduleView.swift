//
//  FriendsScheduleView.swift
//  UFree
//
//  Created by Khang Vu on 07/01/26.
//

import SwiftUI

public struct FriendsScheduleView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var viewModel: FriendsScheduleViewModel
    @ObservedObject var rootViewModel: RootViewModel

    // Display next 5 days
    private var daysToShow: [Date] {
        let today = Date()
        return (0..<5).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: today) }
    }

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    public init(viewModel: FriendsScheduleViewModel, rootViewModel: RootViewModel) {
        self.viewModel = viewModel
        self.rootViewModel = rootViewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !viewModel.friendSchedules.isEmpty {
                    dayFilterSection
                }

                nudgeAllSection

                if viewModel.isLoading && viewModel.friendSchedules.isEmpty {
                    ProgressView()
                        .padding()
                } else if viewModel.friendSchedules.isEmpty {
                    ContentUnavailableView {
                        Label("No friends yet", systemImage: "person.2")
                    } description: {
                        Text("When someone joins you, their free days show up here.")
                    } actions: {
                        Button("Add friends") {
                            rootViewModel.activeTab = .friends
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 24)
                    .adaptiveContentWidth()
                } else if isRegularWidth {
                    friendsMatrixSection
                } else {
                    ForEach(viewModel.friendSchedules) { friendDisplay in
                        FriendScheduleRow(display: friendDisplay, days: daysToShow, viewModel: viewModel)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Who's Free?")
        .navigationBarTitleDisplayMode(.large)
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

    // MARK: - Day Filter

    @ViewBuilder
    private var dayFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who's free on...")
                .font(.headline)
                .padding(.horizontal)

            if isRegularWidth {
                HStack(spacing: 12) {
                    ForEach(daysToShow, id: \.self) { date in
                        dayFilterButton(for: date)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(daysToShow, id: \.self) { date in
                            dayFilterButton(for: date)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func dayFilterButton(for date: Date) -> some View {
        let freeCount = viewModel.freeFriendCount(for: date, friendsSchedules: viewModel.friendSchedules)
        return DayFilterButtonView(
            date: date,
            isSelected: viewModel.selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
            freeCount: freeCount,
            expandsHorizontally: isRegularWidth,
            action: {
                viewModel.toggleDate(date)
            }
        )
    }

    // MARK: - Nudge All

    @ViewBuilder
    private var nudgeAllSection: some View {
        if let selectedDate = viewModel.selectedDate {
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
                            Text("Free \(selectedDate.formatted(.dateTime.weekday(.abbreviated)))?")
                                .fontWeight(.bold)

                            Text("Nudge all \(freeCount) free friends")
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
                .adaptiveContentWidth()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Regular Matrix

    private var friendsMatrixSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Friend")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 140, alignment: .leading)

                ForEach(daysToShow, id: \.self) { date in
                    Text(date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(minWidth: AdaptiveLayout.dayCellMinWidth)
                }

                Color.clear
                    .frame(width: 36)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            ForEach(viewModel.friendSchedules) { friendDisplay in
                FriendScheduleMatrixRow(
                    display: friendDisplay,
                    days: daysToShow,
                    selectedDate: viewModel.selectedDate,
                    isNudging: viewModel.isNudging,
                    onNudge: {
                        HapticManager.medium()
                        Task {
                            await viewModel.sendNudge(
                                to: friendDisplay.id,
                                targetDate: viewModel.selectedDate
                            )
                        }
                    }
                )
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Compact Friend Schedule Row

private struct FriendScheduleRow: View {
    let display: FriendsScheduleViewModel.FriendScheduleDisplay
    let days: [Date]
    let viewModel: FriendsScheduleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

                Button(action: {
                    HapticManager.medium()
                    Task {
                        await viewModel.sendNudge(
                            to: display.id,
                            targetDate: viewModel.selectedDate
                        )
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
        .padding(.horizontal)
    }
}

// MARK: - Regular Matrix Row

private struct FriendScheduleMatrixRow: View {
    let display: FriendsScheduleViewModel.FriendScheduleDisplay
    let days: [Date]
    let selectedDate: Date?
    let isNudging: Bool
    let onNudge: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(String(display.displayName.prefix(1)))
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                    }

                Text(display.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(width: 140, alignment: .leading)

            ForEach(days, id: \.self) { date in
                let status = display.status(for: date)
                let isSelected = selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false
                FriendMatrixStatusCell(status: status, isSelected: isSelected)
                    .frame(maxWidth: .infinity)
                    .frame(minWidth: AdaptiveLayout.dayCellMinWidth)
            }

            Button(action: onNudge) {
                Image(systemName: "hand.wave.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .frame(width: 36, height: 36)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
            .disabled(isNudging)
            .opacity(isNudging ? 0.5 : 1.0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.bottom, 8)
    }
}

private struct FriendMatrixStatusCell: View {
    let status: AvailabilityStatus
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(status.displayColor)
                .frame(width: 28, height: 28)
                .overlay {
                    if status == .free {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    } else if status == .busy {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

            Text(shortStatusLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .cornerRadius(10)
    }

    private var shortStatusLabel: String {
        switch status {
        case .free: return "Free"
        case .busy: return "Busy"
        case .morningOnly: return "AM"
        case .afternoonOnly: return "PM"
        case .eveningOnly: return "Eve"
        case .mixed: return "Mix"
        case .unknown: return "—"
        }
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
        f.dateFormat = "EEE"
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

    return FriendsScheduleView(
        viewModel: viewModel,
        rootViewModel: RootViewModel(authRepository: MockAuthRepository())
    )
}
