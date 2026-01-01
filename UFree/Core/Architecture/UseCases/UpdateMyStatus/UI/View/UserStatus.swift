//
//  UserStatus.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import SwiftUI

enum UserStatus: CaseIterable {
    case checkSchedule
    case busy
    case free

    var title: String {
        switch self {
        case .checkSchedule: return "Check My Schedule"
        case .busy: return "Busy Right Now"
        case .free: return "I'm Free Now!"
        }
    }

    var subtitle: String {
        return "Tap to change your live status"
    }

    var iconName: String {
        switch self {
        case .checkSchedule: return "moon"
        case .busy: return "cup.and.saucer"
        case .free: return "bolt"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .checkSchedule:
            return [Color(hex: "8180f9"), Color(hex: "6e6df0")]
        case .busy:
            return [Color(hex: "7da0c2"), Color(hex: "637d96")]
        case .free:
            return [Color(hex: "6dd69c"), Color(hex: "5abf87")]
        }
    }

    var next: UserStatus {
        switch self {
        case .checkSchedule: return .free
        case .free: return .busy
        case .busy: return .free
        }
    }
}
