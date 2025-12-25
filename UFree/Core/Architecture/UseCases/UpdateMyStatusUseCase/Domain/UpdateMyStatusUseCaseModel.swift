//
//  UpdateMyStatusUseCaseModel.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import Foundation

public protocol UpdateMyStatusUseCaseProtocol {
    func execute(day: DayAvailability) async throws
}

public final class UpdateMyStatusUseCase: UpdateMyStatusUseCaseProtocol {
    private let repository: AvailabilityRepository
    
    public init(repository: AvailabilityRepository) {
        self.repository = repository
    }
    
    public func execute(day: DayAvailability) async throws {
        // Business Logic: Validation
        // Prevent updating status for dates in the past
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayDate = calendar.startOfDay(for: day.date)
        
        if dayDate < today {
            throw UpdateMyStatusUseCaseError.cannotUpdatePastDate
        }
        
        // Update via repository
        try await repository.updateMySchedule(for: day)
    }
}

public enum UpdateMyStatusUseCaseError: Error {
    case cannotUpdatePastDate
}
