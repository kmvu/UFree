//
//  AppCheckConfigurator.swift
//  UFree
//
//  Firebase App Check: App Attest in Release; debug provider in DEBUG / Simulator.
//

import Foundation
import FirebaseCore
import FirebaseAppCheck

/// Installs the App Check provider factory. Must run before `FirebaseApp.configure()`.
enum AppCheckConfigurator {
    static func configureIfNeeded() {
        // Unit-test host must not require App Check tokens / debug providers.
        guard !TestConfiguration.isRunningUnitTests else { return }
        AppCheck.setAppCheckProviderFactory(UFreeAppCheckProviderFactory())
    }
}

final class UFreeAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        #if DEBUG
        // Simulators and DEBUG devices: use the debug provider and register the
        // printed token in Firebase Console → App Check → Manage debug tokens.
        return AppCheckDebugProvider(app: app)
        #else
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        } else {
            return DeviceCheckProvider(app: app)
        }
        #endif
    }
}
