//
//  UpdateMyStatusUseCaseUIIntegrationTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 22/12/25.
//

import XCTest
import Combine
@testable import UFree

// MARK: - Helpers

// NOTE: This helper is for deprecated UIKit template code
// The new implementation uses SwiftUI with MyScheduleView
// This test is kept for compatibility with old template tests
private func makeUpdateMyStatusUseCase() -> UpdateMyStatusUseCase {
    let repository = MockAvailabilityRepository()
    return UpdateMyStatusUseCase(repository: repository)
}

@MainActor
final class UpdateMyStatusUseCaseUIIntegrationTests: XCTestCase {
    
    func test_updatemystatususecaseView_hasTitle() {
        let (sut, _) = makeSUT()
        
        XCTAssertEqual(sut.title, UpdateMyStatusUseCasePresenter.title)
    }
    
    // MARK: - Helpers
    
    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (UIViewController, LoaderSpy) {
        let loader = LoaderSpy()
        let sut = UpdateMyStatusUseCaseComposer.LUpdateMyStatusUseCaseComposedWith(loader: loader.loadPublisher)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(loader, file: file, line: line)
        return (sut, loader)
    }
    
    @MainActor
    private class LoaderSpy {
        private var requests = [PassthroughSubject<UpdateMyStatusUseCase, Error>]()
        
        var loadCallCount: Int {
            return requests.count
        }
        
        func loadPublisher() -> AnyPublisher<UpdateMyStatusUseCase, Error> {
            let publisher = PassthroughSubject<UpdateMyStatusUseCase, Error>()
            requests.append(publisher)
            return publisher.eraseToAnyPublisher()
        }
        
        func completeLoading(with LUpdateMyStatusUseCase: UpdateMyStatusUseCase = makeUpdateMyStatusUseCase(), at index: Int = 0) {
            requests[index].send(LUpdateMyStatusUseCase)
            requests[index].send(completion: .finished)
        }
        
        func completeLoadingWithError(at index: Int = 0) {
            requests[index].send(completion: .failure(anyNSError()))
        }
    }
}
