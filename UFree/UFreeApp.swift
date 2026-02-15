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
import FirebaseAnalytics


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
        Analytics.setAnalyticsCollectionEnabled(true)
        #else
        // Debug builds: disable analytics to avoid noise during development
        Analytics.setAnalyticsCollectionEnabled(false)
        #endif
        
        // Log app launch
        AnalyticsManager.log(.appLaunched)
        
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
            // Ensure Application Support directory exists (fixes CI simulator issues)
            // Skip if running unit tests (they use in-memory containers)
            if !TestConfiguration.isRunningUnitTests {
                let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                if let applicationSupport = paths.first {
                    try? FileManager.default.createDirectory(
                        at: applicationSupport,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                }
            }
            
            // Use in-memory storage for unit tests, disk storage for production/UI tests
            let isInMemory = TestConfiguration.isRunningUnitTests
            let configuration = ModelConfiguration(isStoredInMemoryOnly: isInMemory)
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
