//
//  UFreeApp.swift
//  UFree
//
//  Created by Khang Vu on 19/12/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseCrashlytics


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase only if GoogleService-Info.plist exists (not in unit tests)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Enable Crashlytics crash reporting for distribution builds
        #if !DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
        
        return true
    }
}


@main
struct UFreeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // 1. Initialize SwiftData container for persistence
    let container: ModelContainer
    
    // 2. Initialize auth repository
    let authRepository: AuthRepository
    
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
        
        // Initialize auth repository
        // Configure Firebase if not already done
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Use Firebase if successfully configured
        if FirebaseApp.app() != nil {
            authRepository = FirebaseAuthRepository()
        } else {
            authRepository = MockAuthRepository()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                RootView(
                    container: container,
                    authRepository: authRepository
                )
            }
        }
    }
}
