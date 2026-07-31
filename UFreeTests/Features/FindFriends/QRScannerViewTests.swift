//
//  QRScannerViewTests.swift
//  UFreeTests
//

import AVFoundation
import SwiftUI
import UIKit
import XCTest
@testable import UFree

/// Covers the parts of the QR scanner that do not need a camera.
///
/// `ScannerViewController.viewDidLoad` bails out as soon as `AVCaptureDevice.default(for:)`
/// returns nil, which it always does in the simulator, so the capture pipeline itself stays
/// out of reach. The `UIViewControllerRepresentable` plumbing and the coordinator that
/// reports scans back to SwiftUI are both reachable.
@MainActor
final class QRScannerViewTests: XCTestCase {

    /// Stands in for the `@State` a real caller would bind, so the test can observe what
    /// the coordinator writes back.
    private final class CodeBox {
        var value: String?
    }

    private var box: CodeBox!

    override func setUp() {
        super.setUp()
        box = CodeBox()
    }

    override func tearDown() {
        box = nil
        super.tearDown()
    }

    private func makeView() -> QRScannerView {
        let box = self.box!
        return QRScannerView(
            scannedCode: Binding(get: { box.value }, set: { box.value = $0 })
        )
    }

    // MARK: - Representable Plumbing

    /// `UIViewControllerRepresentableContext` has no public initialiser, so
    /// `makeUIViewController` and `updateUIViewController` are only reachable by letting
    /// SwiftUI drive the representable.
    func test_hosting_buildsTheScannerViewController() {
        ViewHost.render(makeView(), size: CGSize(width: 402, height: 600))
    }

    func test_hosting_survivesRepeatedLayoutPasses() {
        // A second layout pass routes through `updateUIViewController` rather than making a
        // new controller.
        ViewHost.render(makeView(), size: CGSize(width: 402, height: 600), layoutPasses: 3)
    }

    // MARK: - Coordinator

    func test_didFindCode_writesTheCodeBackToTheBinding() {
        let coordinator = makeView().makeCoordinator()

        coordinator.didFindCode("ufree://profile/u1")

        XCTAssertEqual(box.value, "ufree://profile/u1")
    }

    func test_didFindCode_overwritesAnEarlierScan() {
        let coordinator = makeView().makeCoordinator()

        coordinator.didFindCode("first")
        coordinator.didFindCode("second")

        XCTAssertEqual(box.value, "second")
    }

    func test_didFailWithError_leavesTheBindingUntouched() {
        let coordinator = makeView().makeCoordinator()

        coordinator.didFailWithError(NSError(domain: "AVFoundation", code: -11814))

        XCTAssertNil(box.value)
    }

    // MARK: - View Controller Lifecycle

    func test_viewDidLoad_withoutACamera_stopsBeforeBuildingThePipeline() {
        let controller = ScannerViewController()

        controller.loadViewIfNeeded()

        XCTAssertNotNil(controller.captureSession, "The session is created before the device check")
        XCTAssertNil(controller.previewLayer, "The preview layer is only built once a device is found")
    }

    func test_viewWillDisappear_withAnIdleSession_doesNotThrow() {
        let controller = ScannerViewController()
        controller.loadViewIfNeeded()

        controller.viewWillDisappear(false)

        XCTAssertFalse(controller.captureSession.isRunning)
    }

    func test_chrome_hidesStatusBarAndLocksToPortrait() {
        let controller = ScannerViewController()

        XCTAssertTrue(controller.prefersStatusBarHidden)
        XCTAssertEqual(controller.supportedInterfaceOrientations, .portrait)
    }
}
