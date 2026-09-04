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
    /// When true, I’m free and at least one friend is free on this day.
    var isMutualFree: Bool = false
    /// When true, the button fills available width (regular-width day filters).
    var expandsHorizontally: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.selection()
            action()
        }) {
            VStack(spacing: 4) {
                // Weekday (abbreviated)
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .textCase(.uppercase)
                
                // Day number
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .primary)
                
                // Free count badge
                if freeCount > 0 {
                    VStack(spacing: 3) {
                        HStack(spacing: 2) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8))
                            Text("\(freeCount)")
                                .font(.system(size: 10, weight: .black))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isSelected ? .white : Color.accentColor)
                        .foregroundStyle(isSelected ? Color.accentColor : .white)
                        .clipShape(Capsule())

                        if isMutualFree {
                            Text("Both")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(isSelected ? .white : Color.green)
                        }
                    }
                } else {
                    Circle()
                        .fill(isSelected ? .white.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 4, height: 4)
                        .padding(.top, 4)
                }
            }
            .frame(width: expandsHorizontally ? nil : 64)
            .frame(maxWidth: expandsHorizontally ? .infinity : nil)
            .frame(height: isMutualFree && freeCount > 0 ? 104 : 94)
            .background(
                ZStack {
                    if isSelected {
                        Color.accentColor
                    } else {
                        Color(UIColor.secondarySystemGroupedBackground)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
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
                date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86_400),
                isSelected: true,
                freeCount: 2,
                action: {}
            )
            
            DayFilterButtonView(
                date: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date().addingTimeInterval(172_800),
                isSelected: false,
                freeCount: 0,
                action: {}
            )
        }
        .padding()
    }
}
