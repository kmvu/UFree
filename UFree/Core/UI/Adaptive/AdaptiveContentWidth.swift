//
//  AdaptiveContentWidth.swift
//  UFree
//

import SwiftUI

enum AdaptiveLayout {
    /// Readable column width for forms and secondary content on regular-width screens.
    static let readableContentMaxWidth: CGFloat = 560
    /// Slightly narrower column for auth and dense forms.
    static let formContentMaxWidth: CGFloat = 480
    /// Minimum width for day cells in Who's Free matrix / schedule grids.
    static let dayCellMinWidth: CGFloat = 56
    /// Collapsed status banner height on compact height (landscape phone).
    static let statusBannerCollapsedHeightCompact: CGFloat = 88
    /// Collapsed status banner height on regular height.
    static let statusBannerCollapsedHeightRegular: CGFloat = 110
}

/// Centers content and caps its width on regular-size screens so forms don't stretch edge-to-edge.
struct AdaptiveContentWidthModifier: ViewModifier {
    let maxWidth: CGFloat

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    func adaptiveContentWidth(_ maxWidth: CGFloat = AdaptiveLayout.readableContentMaxWidth) -> some View {
        modifier(AdaptiveContentWidthModifier(maxWidth: maxWidth))
    }
}
