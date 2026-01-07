//
//  DayStatusCardView.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import SwiftUI

struct DayStatusCardView: View {
    let day: DayAvailability
    let color: Color
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Day Name
            Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.subheadline)
                .foregroundColor(color)

            // Day Number
            Text(day.date.formatted(.dateTime.day()))
                .font(.headline)
                .foregroundColor(color)

            // Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: iconFor(day.status))
                    .foregroundColor(color)
                    .font(.title)
                    .transition(.scale.combined(with: .opacity))
            }

            // Status Text
            Text(day.status.displayName)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
                .transition(.opacity)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .id(day.id)
        .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.2), value: day.status)
        .onTapGesture {
            HapticManager.light()
            onTap()
        }
    }

    private func iconFor(_ status: AvailabilityStatus) -> String {
        switch status {
        case .free:
            return "checkmark.circle.fill"
        case .busy:
            return "xmark.circle.fill"
        case .morningOnly:
            return "sunrise.fill"
        case .afternoonOnly:
            return "sun.max.fill"
        case .eveningOnly:
            return "moon.stars.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
}

#Preview {
    DayStatusCardView(
        day: DayAvailability(date: Date(), status: .free),
        color: .green,
        onTap: {}
    )
}
