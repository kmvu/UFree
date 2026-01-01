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
