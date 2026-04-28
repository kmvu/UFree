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
        // Configure Firebase when needed (including unit test host so Firestore doesn't throw)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // Skip analytics/crashlytics and app launch log in unit test runs to avoid SDK noise
        if !TestConfiguration.isRunningUnitTests {
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
        }

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
        // Configure Firebase if not already done (AppDelegate usually does this; needed for Firestore in test host)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // In unit tests use mock auth so tests don't depend on network/Firebase Auth
        if TestConfiguration.isRunningUnitTests {
            authRepository = MockAuthRepository()
        } else if FirebaseApp.app() != nil {
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
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onAppear {
                    // This allows dismissing keyboard by tapping anywhere outside
                    UIApplication.shared.addTapGestureRecognizerToWindow()
                }
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Universal Link format: https://ufree.app/profile/{userId}
        guard url.host == "ufree.app" else { return }
        let pathComponents = url.pathComponents
        if pathComponents.count >= 3 && pathComponents[1] == "profile" {
            let userId = pathComponents[2]
            // We need to pass this to RootViewModel or similar
            // In a real implementation, we'd use a shared coordinator or environment object
            NotificationCenter.default.post(name: .didReceiveProfileDeepLink, object: userId)
        }
    }
}

extension Notification.Name {
    static let didReceiveProfileDeepLink = Notification.Name("didReceiveProfileDeepLink")
}

// MARK: - Keyboard Dismissal Helper
extension UIApplication {
    func addTapGestureRecognizerToWindow() {
        guard let windowScene = connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        let tapGesture = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing))
        tapGesture.requiresExclusiveTouchType = false
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        window.addGestureRecognizer(tapGesture)
    }
}

extension UIApplication: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
