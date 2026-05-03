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
            Text(day.status == .mixed ? (day.earliestFreeBlockInfo ?? day.status.displayName) : day.status.displayName)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(isSelected ? .white.opacity(0.9) : color)
                .textCase(.uppercase)
                .multilineTextAlignment(.center) // Ensure alignment for line breaks

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
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.gray.opacity(0.1))

                if day.status == .free {
                    // Full green line for complete free status
                    Capsule()
                        .fill(isSelected ? .white : Color(hex: "6dd69c"))
                        .opacity(isSelected ? 0.8 : 1.0)
                } else {
                    HStack(spacing: 0) {
                        ForEach(day.timeBlocks) { block in
                            Rectangle()
                                .fill(isSelected ? .white : block.status.displayColor)
                                .opacity(isSelected ? (block.status == .free ? 0.8 : 0.2) : 1.0)
                                .frame(width: calculateWidth(for: block, totalWidth: geometry.size.width))
                        }
                    }
                    .clipShape(Capsule())
                }
            }
        }
    }

    private func calculateWidth(for block: TimeBlock, totalWidth: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? day.date.addingTimeInterval(24 * 60 * 60)
        let totalDuration = endOfDay.timeIntervalSince(startOfDay)
        let blockDuration = block.endTime.timeIntervalSince(block.startTime)

        // Ensure we don't divide by zero and handle negative durations gracefully
        guard totalDuration > 0 else { return 0 }
        return (CGFloat(max(0, blockDuration)) / CGFloat(totalDuration)) * totalWidth
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
