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
            VStack(spacing: 6) {
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
                } else {
                    Circle()
                        .fill(isSelected ? .white.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 4, height: 4)
                        .padding(.top, 4)
                }
            }
            .frame(width: 64, height: 94)
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
