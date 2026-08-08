//
//  AdaptivePresentation.swift
//  UFree
//

import SwiftUI

/// Presents content as a popover on regular width, sheet on compact.
/// Prefer size class over device idiom so iPhone landscape, Stage Manager, and Designed-for-iPad Mac share one path.
struct AdaptiveSheetModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    let content: (Item) -> SheetContent

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content
                .popover(item: $item) { value in
                    self.content(value)
                }
        } else {
            content
                .sheet(item: $item) { value in
                    self.content(value)
                        .presentationDetents([.medium, .large])
                }
        }
    }
}

/// Bool-driven variant of adaptive sheet/popover presentation.
struct AdaptiveBoolPresentationModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let content: () -> SheetContent

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content
                .popover(isPresented: $isPresented) {
                    self.content()
                }
        } else {
            content
                .sheet(isPresented: $isPresented) {
                    self.content()
                        .presentationDetents([.medium, .large])
                }
        }
    }
}

extension View {
    func adaptiveSheet<Item: Identifiable, SheetContent: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        modifier(AdaptiveSheetModifier(item: item, content: content))
    }

    func adaptiveSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        modifier(AdaptiveBoolPresentationModifier(isPresented: isPresented, content: content))
    }
}
