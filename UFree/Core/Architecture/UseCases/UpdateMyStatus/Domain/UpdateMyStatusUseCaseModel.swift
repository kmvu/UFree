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
        
        // 1. Prevent updating status for dates in the past
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayDate = calendar.startOfDay(for: day.date)
        
        if dayDate < today {
            throw UpdateMyStatusUseCaseError.cannotUpdatePastDate
        }
        
        // 2. Prevent overlapping time blocks
        try validateNoOverlaps(in: day.timeBlocks)
        
        // Update via repository
        try await repository.updateMySchedule(for: day)
    }
    
    private func validateNoOverlaps(in blocks: [TimeBlock]) throws {
        let sortedBlocks = blocks.sorted { $0.startTime < $1.startTime }
        
        for i in 0..<sortedBlocks.count {
            let current = sortedBlocks[i]
            
            // Validate start is before end
            if current.startTime >= current.endTime {
                throw UpdateMyStatusUseCaseError.invalidTimeRange(blockId: current.id)
            }
            
            // Check overlap with next block
            if i + 1 < sortedBlocks.count {
                let next = sortedBlocks[i + 1]
                if current.endTime > next.startTime {
                    throw UpdateMyStatusUseCaseError.overlappingTimeBlocks(
                        block1Id: current.id,
                        block2Id: next.id
                    )
                }
            }
        }
    }
}

public enum UpdateMyStatusUseCaseError: Error, Equatable {
    case cannotUpdatePastDate
    case overlappingTimeBlocks(block1Id: UUID, block2Id: UUID)
    case invalidTimeRange(blockId: UUID)
}
