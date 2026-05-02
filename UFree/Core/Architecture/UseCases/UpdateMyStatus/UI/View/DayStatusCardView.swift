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

            // Segmented Indicator
            segmentedIndicator
                .frame(height: 6)
                .padding(.horizontal, 4)
                .padding(.top, 4)
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
                    Color(UIColor.secondarySystemGroupedBackground)
                }
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: isSelected ? color.opacity(0.3) : Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .onTapGesture {
            HapticManager.light()
            onTap()
        }
    }

    private var segmentedIndicator: some View {
        HStack(spacing: 2) {
            if day.status == .mixed {
                // Split-color pill for mixed status
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(isSelected ? .white : Color(hex: "6dd69c"))
                        .opacity(isSelected ? 0.8 : 1.0)
                    Rectangle()
                        .fill(isSelected ? .white : Color.gray.opacity(0.3))
                        .opacity(isSelected ? 0.4 : 1.0)
                }
                .clipShape(Capsule())
            } else if isFullDayFree() {
                Capsule()
                    .fill(isSelected ? .white : Color(hex: "6dd69c"))
                    .opacity(isSelected ? 0.8 : 1.0)
            } else {
                // Morning (9AM - 12PM)
                segment(for: 9, to: 12)
                
                // Afternoon (12PM - 5PM)
                segment(for: 12, to: 17)
                
                // Evening (5PM - 10PM)
                segment(for: 17, to: 22)
            }
        }
    }
    
    private func segment(for startHour: Int, to endHour: Int) -> some View {
        let isFree = statusForWindowIsFree(startHour: startHour, endHour: endHour)
        return Capsule()
            .fill(isSelected ? .white : (isFree ? Color(hex: "6dd69c") : Color.gray.opacity(0.3)))
            .opacity(isSelected ? (isFree ? 0.8 : 0.2) : 1.0)
    }
    
    private func isFullDayFree() -> Bool {
        if day.status == .free { return true }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)
        
        // Core active hours: 9 AM to 10 PM
        let activeStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!
        let activeEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: startOfDay)!
        
        // Check if the entire active period is covered by free blocks
        let freeBlocks = day.timeBlocks.filter { $0.status == .free }.sorted { $0.startTime < $1.startTime }
        guard !freeBlocks.isEmpty else { return false }
        
        if freeBlocks.first!.startTime > activeStart || freeBlocks.last!.endTime < activeEnd {
            return false
        }
        
        // Check for gaps within the active period
        var currentEnd = freeBlocks.first!.endTime
        for i in 1..<freeBlocks.count {
            if freeBlocks[i].startTime > currentEnd {
                return false // Gap found
            }
            currentEnd = max(currentEnd, freeBlocks[i].endTime)
        }
        
        return true
    }
    
    private func statusForWindowIsFree(startHour: Int, endHour: Int) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)
        let windowStart = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: startOfDay)!
        let windowEnd = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: startOfDay)!
        
        // If any part of a free block overlaps this window significantly (at least 30 mins or entire window)
        return day.timeBlocks.contains(where: { block in
            block.status == .free && block.startTime < windowEnd && block.endTime > windowStart
        })
    }

    private func iconFor(_ status: AvailabilityStatus) -> String {
        // If the day is exactly one of the specific windows, use that icon
        switch status {
        case .morningOnly: return "sunrise.fill"
        case .afternoonOnly: return "sun.max.fill"
        case .eveningOnly: return "moon.stars.fill"
        default: break
        }
        
        // If there's any free block, show bolt
        if day.timeBlocks.contains(where: { $0.status == .free }) {
            return "bolt.fill"
        }
        
        switch status {
        case .free: return "bolt.fill"
        case .busy: return "cup.and.saucer.fill"
        case .morningOnly: return "sunrise.fill"
        case .afternoonOnly: return "sun.max.fill"
        case .eveningOnly: return "moon.stars.fill"
        case .mixed: return "list.bullet.rectangle.portrait"
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
        case .mixed: return [Color(hex: "6dd69c"), Color(hex: "7da0c2")] // Green to Muted Blue gradient
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
