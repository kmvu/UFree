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
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif
import UserNotifications


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // App Check provider must be installed before FirebaseApp.configure().
        AppCheckConfigurator.configureIfNeeded()

        // Configure Firebase when needed (including unit test host so Firestore doesn't throw)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        // Integration tests: point Auth/Firestore at local emulators before any SDK use.
        FirebaseEmulatorBootstrap.connectIfRequested()

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
            
            // Set up Push Notifications delegates
            // Only if NOT running unit tests to avoid crashes in test host
            UNUserNotificationCenter.current().delegate = self
            #if canImport(FirebaseMessaging)
            Messaging.messaging().delegate = self
            #endif
            
            // Register for remote notifications
            application.registerForRemoteNotifications()
        }

        return true
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notifications even when app is in foreground
        completionHandler([[.banner, .list, .sound]])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Extract senderId from FCM payload (custom data)
        if let senderId = userInfo["senderId"] as? String {
            NotificationCenter.default.post(
                name: .didReceiveProfileDeepLink,
                object: userIdFromSenderId(senderId)
            )
        }
        
        completionHandler()
    }
    
    private func userIdFromSenderId(_ senderId: String) -> String {
        // In a real app, this might involve some parsing if the ID is nested
        return senderId
    }
}

#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        
        // Broadcast the token update so repositories can save it to Firestore
        NotificationCenter.default.post(
            name: .didReceiveFCMToken,
            object: nil,
            userInfo: ["token": token]
        )
    }
}
#endif


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
        AppCheckConfigurator.configureIfNeeded()
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // In unit tests use mock auth so tests don't depend on network/Firebase Auth.
        // UI tests launch with UI_TESTING_MODE and a deterministic signed-in mock user.
        if TestConfiguration.isRunningUnitTests {
            authRepository = MockAuthRepository()
        } else if TestConfiguration.isRunningUITests {
            authRepository = UITestingBootstrap.makeAuthRepository()
        } else if FirebaseApp.app() != nil {
            authRepository = FirebaseAuthRepository()
        } else {
            authRepository = MockAuthRepository()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(
                container: container,
                authRepository: authRepository
            )
            .onAppear {
                // This allows dismissing keyboard by tapping anywhere outside
                UIApplication.shared.addTapGestureRecognizerToWindow()
            }
        }
    }
}

extension Notification.Name {
    static let didReceiveProfileDeepLink = Notification.Name("didReceiveProfileDeepLink")
    static let didReceiveFCMToken = Notification.Name("didReceiveFCMToken")
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
