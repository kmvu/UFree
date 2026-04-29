//
//  StatusBannerView.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import SwiftUI

struct StatusBannerView: View {
    @StateObject private var viewModel = StatusBannerViewModel()
    let scheduleViewModel: MyScheduleViewModel

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
            HStack(spacing: 16) {
                Image(systemName: viewModel.currentStatus.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .font(.system(size: 26))
                    .foregroundColor(.white)
                    .id("icon-\(viewModel.currentStatus)")

                VStack(alignment: .leading, spacing: 2) {
                    Text(Calendar.current.isDateInToday(viewModel.selectedDate) ? "Right Now" : dateString(for: viewModel.selectedDate))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.7))
                        .textCase(.uppercase)

                    Text(viewModel.currentStatus.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .id("title-\(viewModel.currentStatus)")

                    Text(viewModel.currentStatus.subtitle)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoInteractionButtonStyle())
    }

    private var expandedView: some View {
        VStack(spacing: 20) {
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
            .padding(.top, 20)
            .padding(.horizontal, 24)

            HStack(spacing: 12) {
                ForEach([UserStatus.free, .morning, .afternoon, .evening, .busy], id: \.self) { status in
                    statusOptionButton(status)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func statusOptionButton(_ status: UserStatus) -> some View {
        Button(action: {
            HapticManager.medium()
            viewModel.setStatus(status)
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(viewModel.currentStatus == status ? .white : .white.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: status.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(viewModel.currentStatus == status ? .black : .white)
                }
                
                Text(status.title.replacingOccurrences(of: "I'm ", with: "").replacingOccurrences(of: "Free in ", with: "").replacingOccurrences(of: " Right Now", with: ""))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
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
