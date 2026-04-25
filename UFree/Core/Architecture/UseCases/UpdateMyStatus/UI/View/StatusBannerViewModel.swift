//
//  StatusBannerViewModel.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import Foundation
import Combine

@MainActor
final class StatusBannerViewModel: ObservableObject {
    @Published var currentStatus: UserStatus = .checkSchedule
    @Published var isProcessing: Bool = false
    
    private var scheduleViewModel: MyScheduleViewModel?
    private var cancellables = Set<AnyCancellable>()

    func configure(with scheduleViewModel: MyScheduleViewModel) {
        self.scheduleViewModel = scheduleViewModel
        
        // Sync with today's status from scheduleViewModel
        scheduleViewModel.$weeklySchedule
            .receive(on: RunLoop.main)
            .sink { [weak self] schedule in
                self?.updateStatusFromSchedule(schedule)
            }
            .store(in: &cancellables)
    }
    
    private func updateStatusFromSchedule(_ schedule: [DayAvailability]) {
        guard let todayStatus = schedule.first(where: { Calendar.current.isDateInToday($0.date) })?.status else {
            currentStatus = .checkSchedule
            return
        }
        
        // Map AvailabilityStatus to UserStatus
        switch todayStatus {
        case .free: currentStatus = .free
        case .busy: currentStatus = .busy
        default: currentStatus = .checkSchedule
        }
    }

    func cycleStatus() {
        // Prevent concurrent taps while processing
        guard !isProcessing else { return }

        isProcessing = true
        
        // Update status immediately for instant visual feedback
        let nextStatus = currentStatus.next
        currentStatus = nextStatus
        
        // Update the actual schedule
        if let scheduleViewModel = scheduleViewModel {
            if let today = scheduleViewModel.weeklySchedule.first(where: { Calendar.current.isDateInToday($0.date) }) {
                var updatedDay = today
                
                // Map UserStatus back to AvailabilityStatus
                switch nextStatus {
                case .free: updatedDay.status = .free
                case .busy: updatedDay.status = .busy
                case .checkSchedule: updatedDay.status = .busy // Default to busy for checkSchedule
                }
                
                scheduleViewModel.toggleStatus(for: updatedDay)
            }
        }

        // Keep processing flag briefly to show border overlay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isProcessing = false
        }
    }
}
