//
//  StatusBannerViewModel.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class StatusBannerViewModel: ObservableObject {
    @Published var currentStatus: UserStatus = .checkSchedule
    @Published var isProcessing: Bool = false
    @Published var isExpanded: Bool = false
    @Published var selectedDate: Date = Date()
    
    private var scheduleViewModel: MyScheduleViewModel?
    private var cancellables = Set<AnyCancellable>()

    func configure(with scheduleViewModel: MyScheduleViewModel) {
        self.scheduleViewModel = scheduleViewModel
        
        // Sync with weeklySchedule
        scheduleViewModel.$weeklySchedule
            .receive(on: RunLoop.main)
            .sink { [weak self] schedule in
                self?.updateStatusFromSchedule(schedule)
            }
            .store(in: &cancellables)
            
        // Sync with selectedDate in scheduleViewModel
        scheduleViewModel.$selectedDate
            .receive(on: RunLoop.main)
            .sink { [weak self] date in
                self?.setFocusDate(date)
            }
            .store(in: &cancellables)
    }
    
    func setFocusDate(_ date: Date) {
        self.selectedDate = date
        if let schedule = scheduleViewModel?.weeklySchedule {
            updateStatusFromSchedule(schedule)
        }
    }
    
    private func updateStatusFromSchedule(_ schedule: [DayAvailability]) {
        guard let dayStatus = schedule.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) })?.status else {
            currentStatus = .checkSchedule
            return
        }
        
        // Map AvailabilityStatus to UserStatus
        switch dayStatus {
        case .free: currentStatus = .free
        case .morningOnly: currentStatus = .morning
        case .afternoonOnly: currentStatus = .afternoon
        case .eveningOnly: currentStatus = .evening
        case .busy: currentStatus = .busy
        case .unknown: currentStatus = .checkSchedule
        }
    }

    func setStatus(_ status: UserStatus) {
        guard !isProcessing else { return }
        
        isProcessing = true
        currentStatus = status
        
        if let scheduleViewModel = scheduleViewModel {
            if let targetDay = scheduleViewModel.weeklySchedule.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                var updatedDay = targetDay
                
                // Map UserStatus back to AvailabilityStatus
                switch status {
                case .free: updatedDay.status = .free
                case .morning: updatedDay.status = .morningOnly
                case .afternoon: updatedDay.status = .afternoonOnly
                case .evening: updatedDay.status = .eveningOnly
                case .busy: updatedDay.status = .busy
                case .checkSchedule: updatedDay.status = .busy
                }
                
                scheduleViewModel.updateStatus(for: updatedDay)
            }
        }
        
        // Close drawer after selection
        withAnimation(.spring()) {
            isExpanded = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isProcessing = false
        }
    }

    func toggleExpansion() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isExpanded.toggle()
        }
    }
}
