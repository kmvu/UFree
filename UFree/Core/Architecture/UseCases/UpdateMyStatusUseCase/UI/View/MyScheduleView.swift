//
//  MyScheduleView.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import SwiftUI

public struct MyScheduleView: View {
    @StateObject private var viewModel: MyScheduleViewModel
    let rootViewModel: RootViewModel
    
    public init(viewModel: MyScheduleViewModel, rootViewModel: RootViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.rootViewModel = rootViewModel
    }
    
    public var body: some View {
        List(viewModel.weeklySchedule) { day in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.date.formatted(.dateTime.weekday(.wide)))
                        .font(.headline)
                    Text(day.date.formatted(.dateTime.month().day()))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.toggleStatus(for: day)
                }) {
                    Text(day.status.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(colorFor(day.status))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("My Week")
        .navigationSubtitle("Manage your availability")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive, action: {
                        rootViewModel.signOut()
                    }) {
                        Label("Sign Out", systemImage: "power")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                }
            }
        }
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
    
    private func colorFor(_ status: AvailabilityStatus) -> Color {
        switch status {
        case .free:
            return .green
        case .busy:
            return .red
        case .eveningOnly:
            return .orange
        case .unknown:
            return .gray
        }
    }
}

#Preview {
    NavigationView {
        MyScheduleView(
            viewModel: MyScheduleViewModel(
                updateUseCase: UpdateMyStatusUseCase(repository: MockAvailabilityRepository()),
                repository: MockAvailabilityRepository()
            ),
            rootViewModel: RootViewModel(authRepository: MockAuthRepository())
        )
    }
}

