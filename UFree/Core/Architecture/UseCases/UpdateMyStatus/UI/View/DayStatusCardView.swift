//
//  DayStatusCardView.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import SwiftUI

struct DayStatusCardView: View {
    let day: DayAvailability
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Day Name
            Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .white : .secondary)

            // Day Number
            Text(day.date.formatted(.dateTime.day()))
                .font(.headline)
                .foregroundColor(isSelected ? .white : .primary)

            // Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? .white.opacity(0.2) : color.opacity(0.1))
                    .frame(width: 54, height: 54)

                Image(systemName: iconFor(day.status))
                    .foregroundColor(isSelected ? .white : color)
                    .font(.title2)
            }
            .padding(.vertical, 4)

            // Status Text
            Text(day.status.displayName)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(isSelected ? .white.opacity(0.9) : color)
                .textCase(.uppercase)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            ZStack {
                if isSelected {
                    LinearGradient(
                        colors: gradientColors(for: day.status),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.white
                }
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: isSelected ? color.opacity(0.3) : Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .onTapGesture {
            HapticManager.light()
            onTap()
        }
    }

    private func iconFor(_ status: AvailabilityStatus) -> String {
        switch status {
        case .free: return "bolt.fill"
        case .busy: return "cup.and.saucer.fill"
        case .morningOnly: return "sunrise.fill"
        case .afternoonOnly: return "sun.max.fill"
        case .eveningOnly: return "moon.stars.fill"
        case .unknown: return "calendar"
        }
    }

    private func gradientColors(for status: AvailabilityStatus) -> [Color] {
        switch status {
        case .free: return [Color(hex: "6dd69c"), Color(hex: "5abf87")]
        case .busy: return [Color(hex: "7da0c2"), Color(hex: "637d96")]
        case .morningOnly: return [Color(hex: "FFD97D"), Color(hex: "FFB347")]
        case .afternoonOnly: return [Color(hex: "FF9A8B"), Color(hex: "FF6A88")]
        case .eveningOnly: return [Color(hex: "A18CD1"), Color(hex: "FBC2EB")]
        case .unknown: return [Color(hex: "8180f9"), Color(hex: "6e6df0")]
        }
    }
}

#Preview {
    DayStatusCardView(
        day: DayAvailability(date: Date(), status: .free),
        isSelected: true,
        color: .green,
        onTap: {}
    )
}
