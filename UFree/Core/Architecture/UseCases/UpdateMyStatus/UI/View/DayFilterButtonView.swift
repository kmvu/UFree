//
//  DayFilterButtonView.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import SwiftUI

struct DayFilterButtonView: View {
    let date: Date
    let isSelected: Bool
    let freeCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.selection()
            action()
        }) {
            VStack(spacing: 8) {
                // Weekday (abbreviated)
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? .white : .secondary)
                
                // Day number
                Text(date.formatted(.dateTime.day()))
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                // Free count badge
                if freeCount > 0 {
                    Text("\(freeCount) free")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? .white.opacity(0.3) : .green.opacity(0.2))
                        .foregroundStyle(isSelected ? .white : .green)
                        .clipShape(Capsule())
                } else {
                    // Empty state to maintain layout height
                    Text(" ")
                        .font(.system(size: 10))
                        .padding(.vertical, 2)
                }
            }
            .frame(width: 60, height: 90)
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(NoInteractionButtonStyle())
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            DayFilterButtonView(
                date: Date(),
                isSelected: false,
                freeCount: 3,
                action: {}
            )
            
            DayFilterButtonView(
                date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
                isSelected: true,
                freeCount: 2,
                action: {}
            )
            
            DayFilterButtonView(
                date: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
                isSelected: false,
                freeCount: 0,
                action: {}
            )
        }
        .padding()
    }
}
