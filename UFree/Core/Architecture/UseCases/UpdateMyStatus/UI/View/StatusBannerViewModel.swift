//
//  StatusBannerViewModel.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import Foundation
import Combine

@MainActor
final class StatusBannerViewModel: ObservableObject {
    @Published var currentStatus: UserStatus = .checkSchedule
    @Published var isProcessing: Bool = false

    func cycleStatus() {
        // Prevent concurrent taps while processing
        guard !isProcessing else { return }

        isProcessing = true
        
        // Update status immediately for instant visual feedback
        currentStatus = currentStatus.next

        // Keep processing flag briefly to show border overlay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isProcessing = false
        }
    }
}
