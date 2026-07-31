//
//  ButtonStylesTests.swift
//  UFreeTests
//

import SwiftUI
import XCTest
@testable import UFree

/// `ButtonStyle.makeBody` only runs once the styled button is laid out, so both styles are
/// exercised by hosting a button rather than by calling `makeBody` directly.
@MainActor
final class ButtonStylesTests: XCTestCase {

    func test_noInteractionStyle_rendersItsLabelUnchanged() {
        ViewHost.render(
            Button("Tap me") {}.buttonStyle(NoInteractionButtonStyle()),
            size: CGSize(width: 320, height: 120)
        )
    }

    func test_interactiveStyle_rendersItsLabel() {
        ViewHost.render(
            Button("Tap me") {}.buttonStyle(InteractiveButtonStyle()),
            size: CGSize(width: 320, height: 120)
        )
    }

    func test_bothStyles_composeWithOtherModifiers() {
        ViewHost.render(
            VStack {
                Button { } label: {
                    Label("Primary", systemImage: "checkmark")
                }
                .buttonStyle(InteractiveButtonStyle())

                Button { } label: {
                    Label("Secondary", systemImage: "xmark")
                }
                .buttonStyle(NoInteractionButtonStyle())
            },
            size: CGSize(width: 320, height: 240)
        )
    }
}
