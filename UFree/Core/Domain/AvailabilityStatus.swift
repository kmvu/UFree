//
//  AvailabilityStatus.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import Foundation

public enum AvailabilityStatus: Int, Codable, CaseIterable {
    case busy = 0
    case free = 1
    case morningOnly = 2
    case afternoonOnly = 3
    case eveningOnly = 4
    case unknown = 5  // For days not yet set in Firestore
    
    public var displayName: String {
        switch self {
        case .busy: return "Busy"
        case .free: return "Free"
        case .morningOnly: return "Morning"
        case .afternoonOnly: return "Afternoon"
        case .eveningOnly: return "Evening"
        case .unknown: return "Unknown"
        }
    }
}

