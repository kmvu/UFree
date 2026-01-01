//
//  MyScheduleView.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import SwiftUI

public struct MyScheduleView: View {
    @StateObject private var viewModel: MyScheduleViewModel
    @State private var selectedDay: Date?

    public init(viewModel: MyScheduleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection

                // Main Content
                if viewModel.weeklySchedule.isEmpty {
                    emptyStateSection
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Status Banner
                            statusBannerSection

                            // My Week Carousel
                            myWeekCarouselSection

                            // Who's free on... Filter
                            whosFreOnFilterSection
                        }
                        .padding()
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("UFree")
            .task {
                await viewModel.loadSchedule()
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

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Text("UFree")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button(action: {
                Task {
                    await viewModel.loadSchedule()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var statusBannerSection: some View {
        ZStack {
            // Background Layer with Gradient
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "8180f9"), Color(hex: "6e6df0")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 120)

            // Content Layer
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "moon")
                    .font(.system(size: 28))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Check My Schedule")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)

                    Text("Tap to change your live status")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal)
    }

    private var myWeekCarouselSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Week")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.weeklySchedule) { day in
                        DayStatusCard(
                            day: day,
                            color: colorFor(day.status),
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.weeklySchedule) { day in
                        Button(action: {
                            selectedDay = selectedDay == day.date ? nil : day.date
                        }) {
                            VStack(spacing: 4) {
                                Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.caption)
                                Text(day.date.formatted(.dateTime.day()))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                            .background(selectedDay == day.date ? Color.purple.opacity(0.2) : Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        selectedDay == day.date ? Color.purple : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                        .foregroundColor(.primary)
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

    private func colorFor(_ status: AvailabilityStatus) -> Color {
        switch status {
        case .free:
            return .green
        case .busy:
            return .gray
        case .morningOnly:
            return .yellow
        case .afternoonOnly:
            return .pink
        case .eveningOnly:
            return .orange
        }
    }
}

// MARK: - DayStatusCard Component

struct DayStatusCard: View {
    let day: DayAvailability
    let color: Color
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Day Name
            Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.subheadline)
                .foregroundColor(.gray)

            // Day Number
            Text(day.date.formatted(.dateTime.day()))
                .font(.headline)

            // Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: iconFor(day.status))
                    .foregroundColor(color)
                    .font(.title)
                    .transition(.scale.combined(with: .opacity))
            }

            // Status Text
            Text(day.status.displayName)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
                .transition(.opacity)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .id(day.id)
        .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.2), value: day.status)
        .onTapGesture(perform: onTap)
    }

    private func iconFor(_ status: AvailabilityStatus) -> String {
        switch status {
        case .free:
            return "checkmark.circle.fill"
        case .busy:
            return "xmark.circle.fill"
        case .morningOnly:
            return "sunrise.fill"
        case .afternoonOnly:
            return "sun.max.fill"
        case .eveningOnly:
            return "moon.stars.fill"
        }
    }
}

#Preview {
    MyScheduleView(
        viewModel: MyScheduleViewModel(
            updateUseCase: UpdateMyStatusUseCase(repository: MockAvailabilityRepository()),
            repository: MockAvailabilityRepository()
        )
    )
}
