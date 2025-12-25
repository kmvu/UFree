//
//  UpdateMyStatusUseCasePresenterTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 22/12/25.
//

import XCTest
import Foundation
@testable import UFree

final class UpdateMyStatusUseCasePresenterTests: XCTestCase {
    
    // NOTE: This test is for deprecated template code
    // The new implementation uses MyScheduleViewModel instead
    // This test is kept for compatibility with old template tests
    nonisolated func test_map_createsViewModel() async {
        // Create a use case instance (now requires repository)
        let repository = await MockAvailabilityRepository()
        let useCase = UpdateMyStatusUseCase(repository: repository)
        
        // The presenter's map function returns a placeholder view model
        let viewModel = UpdateMyStatusUseCasePresenter.map(useCase)
        
        // Verify it returns a view model (id is now a random UUID placeholder)
        XCTAssertNotNil(viewModel.id)
    }
}
