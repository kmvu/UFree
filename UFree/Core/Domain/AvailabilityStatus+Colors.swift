//
//  AvailabilityStatus+Colors.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import SwiftUI

extension AvailabilityStatus {
    /// Returns the display color for this availability status
    var displayColor: Color {
        switch self {
        case .free:
            return .green
        case .busy:
            return .gray
        case .morningOnly:
            return .yellow
        case .afternoonOnly:
            return .orange
        case .eveningOnly:
            return .purple
        }
    }
}
