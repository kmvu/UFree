//
//  MyScheduleView.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import SwiftUI

public struct MyScheduleView: View {
    @StateObject private var viewModel: MyScheduleViewModel
    @ObservedObject var rootViewModel: RootViewModel
    @State private var isLoaded = false
    @State private var selectedDayForSheet: DayAvailability?

    public init(viewModel: MyScheduleViewModel, rootViewModel: RootViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.rootViewModel = rootViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Main Content
            if viewModel.weeklySchedule.isEmpty {
                emptyStateSection
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Status Banner (padded) - fades in first (delay 0.1s)
                        StatusBannerView(scheduleViewModel: viewModel)
                            .padding()

                        // My Week Carousel - fades in second (delay 0.2s)
                        myWeekCarouselSection
                            .padding(.vertical, 24)

                        // Who's free on... Filter - fades in last (delay 0.3s)
                        whosFreOnFilterSection
                            .padding(.vertical, 24)
                            
                    }
                    .opacity(isLoaded ? 1 : 0)
                    .offset(y: isLoaded ? 0 : 10)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Bell icon with notification badge
                NotificationBellButton(isPresented: .constant(false))
                
                // Menu with sign out
                Menu {
                    Button(role: .destructive, action: {
                        rootViewModel.signOut()
                    }) {
                        Label("Sign Out", systemImage: "arrow.left.square")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                }
            }
        }

        .task {
            await viewModel.loadSchedule()

            // Trigger staggered animations after content loads
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                isLoaded = true
            }
        }
        .sheet(item: $selectedDayForSheet) { day in
            DayDetailsBottomSheet(day: day) { updatedDay in
                viewModel.updateStatus(for: updatedDay)
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Computed Properties

    private var navigationTitle: String {
        if let name = rootViewModel.currentUser?.displayName, !name.isEmpty {
            return "Hello, \(name)"
        }
        return "Hello"
    }

    // MARK: - Sections

    private var myWeekCarouselSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Week")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.weeklySchedule) { day in
                        DayStatusCardView(
                            day: day,
                            isSelected: Calendar.current.isDate(day.date, inSameDayAs: viewModel.selectedDate),
                            color: day.status.displayColor,
                            onTap: {
                                withAnimation(.spring()) {
                                    viewModel.selectedDate = day.date
                                }
                                HapticManager.light()
                                selectedDayForSheet = day
                            }
                        )
                        .onLongPressGesture {
                            HapticManager.medium()
                            selectedDayForSheet = day
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }

    private var whosFreOnFilterSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(discoveryTitle)
                    .font(.headline)
                
                if freeFriendsForSelectedDate.count > 0 {
                    let count = freeFriendsForSelectedDate.count
                    Text("\(count) \(count == 1 ? "friend is" : "friends are") free to hang out")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("No friends marked as free for this day yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.weeklySchedule) { day in
                        DayFilterButtonView(
                            date: day.date,
                            isSelected: rootViewModel.friendsScheduleViewModel?.selectedDate.map { Calendar.current.isDate($0, inSameDayAs: day.date) } ?? false,
                            freeCount: rootViewModel.friendsScheduleViewModel?.freeFriendCount(for: day.date, friendsSchedules: rootViewModel.friendsScheduleViewModel?.friendSchedules ?? []) ?? 0,
                            action: {
                                withAnimation(.spring()) {
                                    rootViewModel.friendsScheduleViewModel?.toggleDate(day.date)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            
            // Discovery Results
            if !freeFriendsForSelectedDate.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: -10) {
                                ForEach(freeFriendsForSelectedDate.prefix(5)) { friend in
                                    ZStack {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.1))
                                            .frame(width: 44, height: 44)
                                        
                                        Text(friend.displayName.prefix(1).uppercased())
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.accentColor)
                                    }
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                }
                                
                                if freeFriendsForSelectedDate.count > 5 {
                                    ZStack {
                                        Circle()
                                            .fill(Color(.systemGray5))
                                            .frame(width: 44, height: 44)
                                        
                                        Text("+\(freeFriendsForSelectedDate.count - 5)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                }
                            }
                            .padding(.leading, 10)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if let date = rootViewModel.friendsScheduleViewModel?.selectedDate {
                                Task {
                                    await rootViewModel.friendsScheduleViewModel?.nudgeAllFree(for: date)
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.wave.fill")
                                Text("Nudge All")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var discoveryTitle: String {
        guard let selectedDate = rootViewModel.friendsScheduleViewModel?.selectedDate else {
            return "Who's free on..."
        }
        
        if Calendar.current.isDateInToday(selectedDate) {
            return "Free Right Now"
        } else if Calendar.current.isDateInTomorrow(selectedDate) {
            return "Free Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return "Free on \(formatter.string(from: selectedDate))"
        }
    }

    private var freeFriendsForSelectedDate: [FriendsScheduleViewModel.FriendScheduleDisplay] {
        guard let selectedDate = rootViewModel.friendsScheduleViewModel?.selectedDate,
              let friendSchedules = rootViewModel.friendsScheduleViewModel?.friendSchedules else {
            return []
        }
        
        return friendSchedules.filter { friendSchedule in
            // Check if friend has any "free" block on that day
            if let dayStatus = friendSchedule.userSchedule.weeklyStatus.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                return dayStatus.timeBlocks.contains { $0.status == .free }
            }
            return false
        }
    }

    private var emptyStateSection: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("No Friends Yet")
                    .font(.headline)
                Text("Invite friends to see their availability")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                rootViewModel.activeTab = .friends
            }) {
                Text("Find Friends")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.accentColor)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(InteractiveButtonStyle())
            .padding()

            Spacer()
        }
        .padding()
    }
}

#Preview {
    MyScheduleView(
        viewModel: MyScheduleViewModel(
            updateUseCase: UpdateMyStatusUseCase(repository: MockAvailabilityRepository()),
            repository: MockAvailabilityRepository()
        ),
        rootViewModel: RootViewModel(authRepository: MockAuthRepository())
    )
}
