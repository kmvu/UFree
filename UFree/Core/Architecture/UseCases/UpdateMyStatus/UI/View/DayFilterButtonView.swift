//
//  DayFilterButtonView.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import SwiftUI

struct DayFilterButtonView: View {
    let day: DayAvailability
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption)
                Text(day.date.formatted(.dateTime.day()))
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.purple.opacity(0.2) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.purple : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .foregroundColor(.primary)
    }
}

#Preview {
    DayFilterButtonView(
        day: DayAvailability(date: Date(), status: .free),
        isSelected: false,
        onTap: {}
    )
}
