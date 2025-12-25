//
//  MyScheduleViewModel.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import Foundation
import Combine

@MainActor
public final class MyScheduleViewModel: ObservableObject {
    @Published public var weeklySchedule: [DayAvailability] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    private let updateUseCase: UpdateMyStatusUseCaseProtocol
    private let repository: AvailabilityRepository
    
    public init(updateUseCase: UpdateMyStatusUseCaseProtocol, repository: AvailabilityRepository) {
        self.updateUseCase = updateUseCase
        self.repository = repository
        setupInitialWeek()
    }
    
    private func setupInitialWeek() {
        // Generate next 7 days starting from today with 'unknown' status
        let calendar = Calendar.current
        let today = Date()
        
        self.weeklySchedule = (0..<7).compactMap { i in
            guard let date = calendar.date(byAdding: .day, value: i, to: today) else {
                return nil
            }
            return DayAvailability(date: date, status: .unknown)
        }
    }
    
    public func loadSchedule() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let userSchedule = try await repository.getMySchedule()
            
            // Merge loaded schedule with generated week
            // If a day exists in loaded schedule, use it; otherwise keep generated day
            let calendar = Calendar.current
            for (index, generatedDay) in weeklySchedule.enumerated() {
                if let loadedDay = userSchedule.weeklyStatus.first(where: { day in
                    calendar.isDate(day.date, inSameDayAs: generatedDay.date)
                }) {
                    weeklySchedule[index] = loadedDay
                }
            }
        } catch {
            errorMessage = "Failed to load schedule: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    public func toggleStatus(for day: DayAvailability) {
        guard let index = weeklySchedule.firstIndex(where: { $0.id == day.id }) else {
            return
        }
        
        // Cycle to next status
        let nextStatus = cycleStatus(weeklySchedule[index].status)
        weeklySchedule[index].status = nextStatus
        
        // Update via use case
        let updatedDay = weeklySchedule[index]
        Task {
            do {
                try await updateUseCase.execute(day: updatedDay)
            } catch {
                // Revert on error
                await MainActor.run {
                    weeklySchedule[index].status = day.status
                    errorMessage = "Failed to update status: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func cycleStatus(_ current: AvailabilityStatus) -> AvailabilityStatus {
        switch current {
        case .unknown: return .free
        case .free: return .busy
        case .busy: return .eveningOnly
        case .eveningOnly: return .free
        }
    }
}

