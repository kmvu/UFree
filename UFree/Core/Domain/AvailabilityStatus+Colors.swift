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
            return Color(hex: "6dd69c")
        case .busy:
            return .gray
        case .morningOnly:
            return .yellow
        case .afternoonOnly:
            return .orange
        case .eveningOnly:
            return .purple
        case .unknown:
            return Color(red: 0.7, green: 0.7, blue: 0.7) // Light gray for unknown
        case .mixed:
            // For mixed days, we use the free color (green) because it indicates 
            // there is at least some availability.
            return Color(hex: "6dd69c")
        }
    }
}
