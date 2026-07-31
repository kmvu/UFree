//
//  ViewHost.swift
//  UFreeTests
//

import SwiftUI
import UIKit
import XCTest

/// Renders SwiftUI views inside a real `UIWindow` so their `body` actually executes.
///
/// SwiftUI is lazy: constructing a view value runs no layout code at all. Attaching it
/// to a hosting controller in a visible window and forcing a layout pass is what drives
/// `body`, `@State` initialisation, and modifier evaluation — which is what these tests
/// are asserting on.
@MainActor
enum ViewHost {

    /// Tall enough that `List` / `ScrollView` content is realised in one pass rather
    /// than being deferred until the user scrolls.
    ///
    /// `nonisolated` so it can be used as a default argument, which is evaluated
    /// outside the enclosing actor's isolation.
    nonisolated static let defaultSize = CGSize(width: 402, height: 2400)

    /// Permanent root of the shared window. Each render adds its hosting controller as a
    /// child of this container rather than becoming the window root itself.
    ///
    /// Assigning `rootViewController` — or toggling `isHidden` — starts appearance
    /// transitions that UIKit does not always finish before the next render tears the
    /// hierarchy down again. Containment keeps the window's root (and its visibility)
    /// fixed for the lifetime of the process; only the child comes and goes.
    private static let container: UIViewController = {
        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground
        return controller
    }()

    /// One window shared by every render, rather than one window per render.
    ///
    /// Attached to the test host's `UIWindowScene`: a window built with `UIWindow(frame:)`
    /// has no scene, and a scene-less window cannot become key in a scene-based app.
    /// Kept permanently visible above the host app's own window so key status is stable
    /// and scene activation notifications are not fired by hide/show churn.
    private static let window: UIWindow = {
        guard let scene = hostWindowScene else {
            fatalError(
                "ViewHost requires a UIWindowScene. The test host app's scene was not ready; " +
                "call ViewHost only after XCTest has launched the app."
            )
        }

        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: defaultSize)
        window.windowLevel = .normal + 1
        window.rootViewController = container
        window.makeKeyAndVisible()
        return window
    }()

    private static var hostWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    /// Hosts `view`, forces layout, and detaches it again.
    static func render<V: View>(
        _ view: V,
        size: CGSize = defaultSize,
        layoutPasses: Int = 2
    ) {
        autoreleasepool {
            let controller = attach(view, size: size)

            for _ in 0..<layoutPasses {
                layOut(controller)
                RunLoop.current.run(until: Date())
            }

            detach(controller)
        }
    }

    /// What a render observed while the view was hosted.
    struct RenderReport {
        /// Whether the view put a modal on screen — `.alert`, `.sheet`,
        /// `.confirmationDialog`, `.fullScreenCover` — at any point during the render.
        ///
        /// Sampled while the view is still hosted rather than inferred afterwards. A
        /// modal's `isPresented` binding writes back when SwiftUI unwinds the presentation
        /// during teardown, but whether that write lands before the render call returns
        /// depends on how many run loop turns UIKit needed, so it is not something a test
        /// can assert on.
        var didPresentModal: Bool
    }

    /// Hosts `view`, lets async work settle, then renders again so state updates
    /// triggered from `task {}` / `onAppear` are reflected in a second body pass.
    @discardableResult
    static func renderAwaitingUpdates<V: View>(
        _ view: V,
        size: CGSize = defaultSize
    ) async -> RenderReport {
        let controller = attach(view, size: size)

        layOut(controller)

        // `LoginView` (and friends) focus a text field from `onAppear`. Resign that before
        // any `.alert` tries to present — keyboard and alert both count as presentations,
        // and UIKit rejects the second with "while a presentation is in progress".
        Self.window.endEditing(true)
        RunLoop.current.run(until: Date())

        var didPresentModal = false

        // Yields and run loop turns are interleaved because the two drive different halves
        // of the update: `Task.yield()` lets `.task {}` bodies advance, and the state they
        // publish is applied by SwiftUI on the run loop. A presentation needs several turns
        // of both before UIKit has actually put anything on screen.
        for _ in 0..<20 {
            await Task.yield()
            RunLoop.current.run(until: Date())
            didPresentModal = didPresentModal || presentedModal(from: controller) != nil
        }

        layOut(controller)
        RunLoop.current.run(until: Date())
        didPresentModal = didPresentModal || presentedModal(from: controller) != nil

        detach(controller)

        return RenderReport(didPresentModal: didPresentModal)
    }

    /// Renders the same view once per state mutation, so every branch in `body` is
    /// evaluated against a different snapshot of the ViewModel.
    static func render<V: View, Model>(
        _ makeView: (Model) -> V,
        model: Model,
        states: [(String, (Model) -> Void)],
        size: CGSize = defaultSize
    ) {
        for (_, mutate) in states {
            mutate(model)
            render(makeView(model), size: size)
        }
    }

    // MARK: - Hosting Lifecycle

    private static func attach<V: View>(_ view: V, size: CGSize) -> UIHostingController<V> {
        // A leftover alert/sheet from the previous render still counts as "a presentation
        // in progress" for the next one. Clear it before installing a new child.
        clearPresentations()

        Self.window.frame = CGRect(origin: .zero, size: size)
        Self.window.makeKeyAndVisible()

        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .systemBackground
        controller.view.frame = Self.window.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        container.addChild(controller)
        container.view.addSubview(controller.view)
        controller.didMove(toParent: container)

        RunLoop.current.run(until: Date())

        return controller
    }

    private static func layOut(_ controller: UIViewController) {
        controller.view.frame = Self.window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    private static func detach<V: View>(_ controller: UIHostingController<V>) {
        Self.window.endEditing(true)
        RunLoop.current.run(until: Date())

        // Dismiss while the hosting controller is still in the hierarchy so SwiftUI can
        // write `false` back through the `isPresented` binding. Waiting until the modal is
        // actually gone — not just until `dismiss` returns — is what keeps the next
        // `attach` from colliding with a presentation still in flight.
        clearPresentations()

        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()

        for _ in 0..<4 {
            RunLoop.current.run(until: Date())
        }

        clearPresentations()
    }

    /// Dismisses any modal hanging off `container` and spins the run loop until UIKit
    /// reports none left (or a short budget expires).
    private static func clearPresentations() {
        for _ in 0..<20 {
            if container.presentedViewController == nil { return }
            container.dismiss(animated: false)
            RunLoop.current.run(until: Date())
        }
    }

    private static func presentedModal(from controller: UIViewController) -> UIViewController? {
        controller.presentedViewController
            ?? container.presentedViewController
    }
}
