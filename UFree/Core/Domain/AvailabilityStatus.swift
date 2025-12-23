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
    case eveningOnly = 2
    case unknown = 3
    
    public var displayName: String {
        switch self {
        case .busy: return "Busy"
        case .free: return "Free"
        case .eveningOnly: return "Evening Only"
        case .unknown: return "No Status"
        }
    }
}

