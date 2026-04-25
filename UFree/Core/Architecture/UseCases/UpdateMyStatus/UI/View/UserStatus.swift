//
//  UserStatus.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import SwiftUI

enum UserStatus: String, CaseIterable {
    case free
    case morning
    case afternoon
    case evening
    case busy
    case checkSchedule

    var title: String {
        switch self {
        case .free: return "I'm Free Now!"
        case .morning: return "Free in Morning"
        case .afternoon: return "Free in Afternoon"
        case .evening: return "Free in Evening"
        case .busy: return "Busy Right Now"
        case .checkSchedule: return "Check My Schedule"
        }
    }

    var subtitle: String {
        return "Tap to change your status"
    }

    var iconName: String {
        switch self {
        case .free: return "bolt.fill"
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        case .busy: return "cup.and.saucer.fill"
        case .checkSchedule: return "calendar"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .free:
            return [Color(hex: "6dd69c"), Color(hex: "5abf87")]
        case .morning:
            return [Color(hex: "FFD97D"), Color(hex: "FFB347")]
        case .afternoon:
            return [Color(hex: "FF9A8B"), Color(hex: "FF6A88")]
        case .evening:
            return [Color(hex: "A18CD1"), Color(hex: "FBC2EB")]
        case .busy:
            return [Color(hex: "7da0c2"), Color(hex: "637d96")]
        case .checkSchedule:
            return [Color(hex: "8180f9"), Color(hex: "6e6df0")]
        }
    }
}
