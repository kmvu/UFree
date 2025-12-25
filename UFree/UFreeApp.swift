//
//  UFreeApp.swift
//  UFree
//
//  Created by Khang Vu on 19/12/25.
//

import SwiftUI

@main
struct UFreeApp: App {
    // 1. Create the concrete Repository
    let repository = MockAvailabilityRepository()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                // 2. Inject Repository into the Use Case
                let useCase = UpdateMyStatusUseCase(repository: repository)
                
                // 3. Inject Use Case and Repository into the ViewModel
                let viewModel = MyScheduleViewModel(updateUseCase: useCase, repository: repository)
                
                // 4. Pass ViewModel to the View
                MyScheduleView(viewModel: viewModel)
            }
        }
    }
}
