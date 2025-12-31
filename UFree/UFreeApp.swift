//
//  UFreeApp.swift
//  UFree
//
//  Created by Khang Vu on 19/12/25.
//

import SwiftUI
import SwiftData
import FirebaseCore


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}


@main
struct UFreeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // 1. Initialize SwiftData container for persistence
    let container: ModelContainer
    
    init() {
        do {
            // Configure container with PersistentDayAvailability model
            let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try ModelContainer(
                for: PersistentDayAvailability.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                // 2. Create the persistent repository (swapped from MockAvailabilityRepository)
                let repository = SwiftDataAvailabilityRepository(container: container)
                
                // 3. Inject Repository into the Use Case
                let useCase = UpdateMyStatusUseCase(repository: repository)
                
                // 4. Inject Use Case and Repository into the ViewModel
                let viewModel = MyScheduleViewModel(updateUseCase: useCase, repository: repository)
                
                // 5. Pass ViewModel to the View
                MyScheduleView(viewModel: viewModel)
            }
        }
    }
}
