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
    @StateObject private var dayFilterViewModel = DayFilterViewModel()
    @State private var isLoaded = false

    public init(viewModel: MyScheduleViewModel, rootViewModel: RootViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.rootViewModel = rootViewModel
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main Content
                if viewModel.weeklySchedule.isEmpty {
                    emptyStateSection
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Status Banner (padded) - fades in first (delay 0.1s)
                            StatusBannerView()
                                .padding()
                                .opacity(isLoaded ? 1 : 0)
                                .offset(y: isLoaded ? 0 : 10)

                            // My Week Carousel - fades in second (delay 0.2s)
                            myWeekCarouselSection
                                .padding(.vertical, 24)
                                .opacity(isLoaded ? 1 : 0)
                                .offset(y: isLoaded ? 0 : 10)

                            // Who's free on... Filter - fades in last (delay 0.3s)
                            whosFreOnFilterSection
                                .padding(.vertical, 24)
                                .opacity(isLoaded ? 1 : 0)
                                .offset(y: isLoaded ? 0 : 10)
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationSubtitle("See when friends are available")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                            color: day.status.displayColor,
                            onTap: {
                                viewModel.toggleStatus(for: day)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var whosFreOnFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who's free on...")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.weeklySchedule) { day in
                        DayFilterButtonView(
                            day: day,
                            isSelected: dayFilterViewModel.selectedDay == day.date,
                            onTap: {
                                dayFilterViewModel.toggleDay(day.date)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
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

            Button(action: {}) {
                Text("Find Friends")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.purple)
                    .cornerRadius(8)
            }
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
