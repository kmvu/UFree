//
//  HapticManager.swift
//  UFree
//
//  Created by Khang Vu on 07/01/26.
//

import UIKit

struct HapticManager {
    /// Light impact feedback (selection, subtle interactions)
    static func light() {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }

    /// Medium impact feedback (primary actions, status changes)
    static func medium() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
    }

    /// Heavy impact feedback (significant changes, confirmations)
    static func heavy() {
        let feedback = UIImpactFeedbackGenerator(style: .heavy)
        feedback.impactOccurred()
    }

    /// Success notification (friend added, data saved)
    static func success() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }

    /// Warning notification (action might have consequences)
    static func warning() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.warning)
    }

    /// Error notification (action failed)
    static func error() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.error)
    }

    /// Selection feedback (subtle for navigation/selection)
    static func selection() {
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }
}
