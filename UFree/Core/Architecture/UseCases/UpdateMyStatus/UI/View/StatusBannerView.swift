//
//  StatusBannerView.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import SwiftUI

struct StatusBannerView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel: StatusBannerViewModel
    let scheduleViewModel: MyScheduleViewModel

    private let statusOptions: [UserStatus] = [.free, .morning, .afternoon, .evening, .busy]

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    init(scheduleViewModel: MyScheduleViewModel) {
        self.init(scheduleViewModel: scheduleViewModel, viewModel: StatusBannerViewModel())
    }

    /// Accepts a pre-built ViewModel so callers can drive the banner's expansion and
    /// status independently of a tap.
    init(scheduleViewModel: MyScheduleViewModel, viewModel: StatusBannerViewModel) {
        self.scheduleViewModel = scheduleViewModel
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    private var collapsedHeight: CGFloat {
        isCompactHeight
            ? AdaptiveLayout.statusBannerCollapsedHeightCompact
            : AdaptiveLayout.statusBannerCollapsedHeightRegular
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isExpanded {
                expandedView
                    .allowsHitTesting(viewModel.isExpanded)
            } else {
                collapsedView
            }
        }
        .background(
            LinearGradient(
                colors: viewModel.currentStatus.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .animation(.easeOut(duration: 0.5), value: viewModel.currentStatus)
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .onAppear {
            viewModel.configure(with: scheduleViewModel)
        }
    }

    private var collapsedView: some View {
        Button(action: {
            HapticManager.medium()
            viewModel.toggleExpansion()
        }) {
            HStack(spacing: isCompactHeight ? 12 : 16) {
                Image(systemName: viewModel.currentStatus.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: isCompactHeight ? 28 : 32, height: isCompactHeight ? 28 : 32)
                    .font(.system(size: isCompactHeight ? 22 : 26))
                    .foregroundColor(.white)
                    .id("icon-\(viewModel.currentStatus)")

                VStack(alignment: .leading, spacing: 2) {
                    Text(Calendar.current.isDateInToday(viewModel.selectedDate) ? "Right Now" : dateString(for: viewModel.selectedDate))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.7))
                        .textCase(.uppercase)

                    Text(viewModel.currentStatus.title(customMixed: viewModel.customMixedTitle))
                        .font(.system(size: isCompactHeight ? 18 : 20, weight: .bold))
                        .foregroundColor(.white)
                        .id("title-\(viewModel.currentStatus)-\(viewModel.customMixedTitle ?? "")")

                    if !isCompactHeight {
                        Text(viewModel.currentStatus.subtitle)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .frame(height: collapsedHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoInteractionButtonStyle())
    }

    private var expandedView: some View {
        VStack(spacing: isCompactHeight ? 12 : 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Calendar.current.isDateInToday(viewModel.selectedDate) ? "Today's Status" : "\(dateString(for: viewModel.selectedDate))'s Status")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Select your availability")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Button(action: {
                    HapticManager.light()
                    viewModel.toggleExpansion()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.top, isCompactHeight ? 12 : 20)
            .padding(.horizontal, 24)

            Group {
                if isRegularWidth {
                    // Keep chips clustered — don't let HStack expand across a wide iPad/Mac pane.
                    HStack(spacing: 16) {
                        ForEach(statusOptions, id: \.self) { status in
                            statusOptionButton(status, expands: false)
                        }
                    }
                    .frame(maxWidth: AdaptiveLayout.statusOptionsClusterMaxWidth)
                    .frame(maxWidth: .infinity)
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            ForEach(statusOptions, id: \.self) { status in
                                statusOptionButton(status, expands: true)
                            }
                        }

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: 12
                        ) {
                            ForEach(statusOptions, id: \.self) { status in
                                statusOptionButton(status, expands: true)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, isCompactHeight ? 12 : 24)
        }
    }

    private func statusOptionButton(_ status: UserStatus, expands: Bool) -> some View {
        Button(action: {
            HapticManager.medium()
            viewModel.setStatus(status)
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(viewModel.currentStatus == status ? .white : .white.opacity(0.2))
                        .frame(width: isCompactHeight ? 40 : 48, height: isCompactHeight ? 40 : 48)

                    Image(systemName: status.iconName)
                        .font(.system(size: isCompactHeight ? 16 : 20))
                        .foregroundColor(viewModel.currentStatus == status ? .black : .white)
                }

                Text(status.title.replacingOccurrences(of: "I'm ", with: "").replacingOccurrences(of: "Free in ", with: "").replacingOccurrences(of: " Right Now", with: ""))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: expands ? nil : 64)
            .frame(maxWidth: expands ? .infinity : nil)
        }
        .buttonStyle(NoInteractionButtonStyle())
    }

    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

#Preview {
    StatusBannerView(
        scheduleViewModel: MyScheduleViewModel(
            updateUseCase: UpdateMyStatusUseCase(repository: MockAvailabilityRepository()),
            repository: MockAvailabilityRepository()
        )
    )
}
