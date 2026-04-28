//
//  ButtonStyles.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import SwiftUI

/// Removes default button interaction feedback (highlight flash)
struct NoInteractionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

/// Provides visual feedback with scale and opacity changes when pressed
struct InteractiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
