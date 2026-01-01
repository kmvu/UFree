//
//  DayFilterViewModel.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import Foundation
import Combine

@MainActor
final class DayFilterViewModel: ObservableObject {
    @Published var selectedDay: Date?

    func toggleDay(_ date: Date) {
        // Set or clear the selected day
        if selectedDay == date {
            selectedDay = nil
        } else {
            selectedDay = date
        }
    }

    func clearSelection() {
        selectedDay = nil
    }
}
