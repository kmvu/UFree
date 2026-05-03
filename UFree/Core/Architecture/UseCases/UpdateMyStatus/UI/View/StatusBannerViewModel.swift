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
    @Published var customMixedTitle: String? = nil
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
        guard let day = schedule.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) else {
            currentStatus = .checkSchedule
            customMixedTitle = nil
            return
        }
        
        let dayStatus = day.status
        
        // Map AvailabilityStatus to UserStatus
        switch dayStatus {
        case .free: 
            currentStatus = .free
            customMixedTitle = nil
        case .morningOnly: 
            currentStatus = .morning
            customMixedTitle = day.earliestFreeBlockInfo?.replacingOccurrences(of: "\n", with: " ")
        case .afternoonOnly: 
            currentStatus = .afternoon
            customMixedTitle = day.earliestFreeBlockInfo?.replacingOccurrences(of: "\n", with: " ")
        case .eveningOnly: 
            currentStatus = .evening
            customMixedTitle = day.earliestFreeBlockInfo?.replacingOccurrences(of: "\n", with: " ")
        case .busy: 
            currentStatus = .busy
            customMixedTitle = nil
        case .mixed: 
            currentStatus = .mixed
            customMixedTitle = day.earliestFreeBlockInfo?.replacingOccurrences(of: "\n", with: " at ")
        case .unknown: 
            currentStatus = .checkSchedule
            customMixedTitle = nil
        }
    }

    func setStatus(_ status: UserStatus) {
        guard !isProcessing && isExpanded else { return }
        
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
                case .mixed: updatedDay.status = .mixed
                case .checkSchedule: updatedDay.status = .busy
                }
                
                scheduleViewModel.updateStatus(for: updatedDay)
            }
        }
        
        // Close drawer after selection
        if NSClassFromString("XCTestCase") != nil {
            isExpanded = false
        } else {
            withAnimation(.spring()) {
                isExpanded = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isProcessing = false
        }
    }

    func toggleExpansion() {
        if NSClassFromString("XCTestCase") != nil {
            isExpanded.toggle()
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }
    }
}
