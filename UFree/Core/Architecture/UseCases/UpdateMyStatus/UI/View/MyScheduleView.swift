//
//  MyScheduleView.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import SwiftUI

public struct MyScheduleView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @StateObject private var viewModel: MyScheduleViewModel
    @ObservedObject var rootViewModel: RootViewModel
    @State private var isLoaded = false
    @State private var showingSettings = false
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

                        // My Week Carousel - availability editing only
                        myWeekCarouselSection
                            .padding(.vertical, 24)

                        // Light invite CTA when still alone (Who's Free lives on home tab)
                        if rootViewModel.friendsScheduleViewModel?.friendSchedules.isEmpty != false {
                            OnboardingCardView {
                                rootViewModel.activeTab = .friends
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                        }
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
                
                // Settings gear icon
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.body)
                }
                
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
        .adaptiveSheet(isPresented: $showingSettings) {
            if let friendRepo = rootViewModel.friendsViewModel?.friendRepository {
                SettingsView(viewModel: SettingsViewModel(
                    authRepository: rootViewModel.authRepository,
                    friendRepository: friendRepo
                ))
            }
        }
        .task {
            await viewModel.loadSchedule()

            // Trigger staggered animations after content loads
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                isLoaded = true
            }
        }
        .adaptiveSheet(item: $selectedDayForSheet) { day in
            DayDetailsBottomSheet(day: day) { updatedDay in
                viewModel.updateStatus(for: updatedDay)
            }
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

            if horizontalSizeClass == .regular {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)], spacing: 16) {
                    ForEach(viewModel.weeklySchedule) { day in
                        dayCard(for: day)
                    }
                }
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.weeklySchedule) { day in
                            dayCard(for: day)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCard(for day: DayAvailability) -> some View {
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
