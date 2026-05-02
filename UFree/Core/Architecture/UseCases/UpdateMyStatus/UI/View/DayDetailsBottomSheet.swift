//
//  DayDetailsBottomSheet.swift
//  UFree
//
//  Created by Cline on 5/1/26.
//

import SwiftUI

struct DayDetailsBottomSheet: View {
    let day: DayAvailability
    let onSave: (DayAvailability) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedBlocks: [TimeBlock]
    @State private var startTime: Date
    @State private var endTime: Date
    
    init(day: DayAvailability, onSave: @escaping (DayAvailability) -> Void) {
        self.day = day
        self.onSave = onSave
        
        let blocks = day.timeBlocks
        self._editedBlocks = State(initialValue: blocks)
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)
        let now = Date()
        
        let initialStart: Date
        if calendar.isDate(now, inSameDayAs: day.date) {
            initialStart = now
        } else {
            initialStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!
        }
        
        self._startTime = State(initialValue: initialStart)
        self._endTime = State(initialValue: calendar.date(byAdding: .hour, value: 1, to: initialStart) ?? initialStart)
    }
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                List {
                    Section(header: Text("Add Free Time")) {
                        VStack(spacing: 16) {
                            DatePickerRow(title: "Starts", icon: "clock", selection: $startTime)
                            
                            Divider()
                                .padding(.leading, 32)
                            
                            DatePickerRow(title: "Ends", icon: "clock.fill", selection: $endTime)
                            
                            if startTime >= endTime {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text("End time must be after start time")
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 32)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.vertical, 8)
                        
                        Button(action: {
                            addCustomBlock()
                            scrollToWindows(proxy)
                        }) {
                            HStack {
                                Spacer()
                                Label("Add Free Window", systemImage: "plus.circle.fill")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                        .disabled(startTime >= endTime)
                        .listRowBackground(startTime >= endTime ? Color.gray.opacity(0.05) : Color.accentColor.opacity(0.1))
                        .foregroundColor(startTime >= endTime ? .gray : .accentColor)
                    }
                    
                    Section(header: Text("Quick Fills")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                QuickFillButton(title: "Morning", icon: "sunrise.fill", color: .orange, isSelected: isQuickFillActive(startHour: 9, endHour: 12)) {
                                    applyQuickFill(startHour: 9, endHour: 12)
                                    scrollToWindows(proxy)
                                }
                                .frame(width: 100)
                                
                                QuickFillButton(title: "Afternoon", icon: "sun.max.fill", color: .yellow, isSelected: isQuickFillActive(startHour: 12, endHour: 17)) {
                                    applyQuickFill(startHour: 12, endHour: 17)
                                    scrollToWindows(proxy)
                                }
                                .frame(width: 100)
                                
                                QuickFillButton(title: "Evening", icon: "moon.stars.fill", color: .purple, isSelected: isQuickFillActive(startHour: 17, endHour: 22)) {
                                    applyQuickFill(startHour: 17, endHour: 22)
                                    scrollToWindows(proxy)
                                }
                                .frame(width: 100)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                    
                    Section(header: Text("Current Windows")) {
                        let freeBlocks = editedBlocks.filter { $0.status == .free }
                        
                        if freeBlocks.isEmpty {
                            Text("No free windows added yet.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(freeBlocks) { block in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(block.startTime.formatted(date: .omitted, time: .shortened) + " - " + block.endTime.formatted(date: .omitted, time: .shortened))
                                            .fontWeight(.semibold)
                                    }
                                    Spacer()
                                    Button(action: { removeBlock(block) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .id(block.id)
                            }
                        }
                    }
                    .id("windows_section")
                }
            }
            .navigationTitle(day.date.formatted(.dateTime.weekday().day().month()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func scrollToWindows(_ proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("windows_section", anchor: .bottom)
        }
    }
    
    private func addCustomBlock() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)
        
        let sComp = calendar.dateComponents([.hour, .minute], from: startTime)
        let eComp = calendar.dateComponents([.hour, .minute], from: endTime)
        
        let finalStart = calendar.date(bySettingHour: sComp.hour!, minute: sComp.minute!, second: 0, of: startOfDay)!
        let finalEnd = calendar.date(bySettingHour: eComp.hour!, minute: eComp.minute!, second: 0, of: startOfDay)!
        
        let newBlock = TimeBlock(startTime: finalStart, endTime: finalEnd, status: .free)
        mergeAndAddBlock(newBlock)
        HapticManager.light()
    }
    
    private func applyQuickFill(startHour: Int, endHour: Int) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)
        
        let qStart = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: startOfDay)!
        let qEnd = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: startOfDay)!
        
        if isQuickFillActive(startHour: startHour, endHour: endHour) {
            subtractFreeRange(startTime: qStart, endTime: qEnd)
            HapticManager.light()
        } else {
            let newBlock = TimeBlock(startTime: qStart, endTime: qEnd, status: .free)
            mergeAndAddBlock(newBlock)
            HapticManager.success()
        }
    }
    
    private func subtractFreeRange(startTime: Date, endTime: Date) {
        var freeBlocks = editedBlocks.filter { $0.status == .free }
        var resultBlocks: [TimeBlock] = []
        
        for block in freeBlocks {
            if block.endTime <= startTime || block.startTime >= endTime {
                // No overlap
                resultBlocks.append(block)
            } else {
                // Overlap exists - we might need to split or truncate
                if block.startTime < startTime {
                    // Left part remains
                    resultBlocks.append(TimeBlock(startTime: block.startTime, endTime: startTime, status: .free))
                }
                
                if block.endTime > endTime {
                    // Right part remains
                    resultBlocks.append(TimeBlock(startTime: endTime, endTime: block.endTime, status: .free))
                }
            }
        }
        
        var finalBlocks = editedBlocks.filter { $0.status != .free }
        finalBlocks.append(contentsOf: resultBlocks)
        
        withAnimation {
            self.editedBlocks = finalBlocks
        }
    }
    
    private func mergeAndAddBlock(_ newBlock: TimeBlock) {
        var freeBlocks = editedBlocks.filter { $0.status == .free }
        freeBlocks.append(newBlock)
        
        // Sort by start time
        freeBlocks.sort { $0.startTime < $1.startTime }
        
        var merged: [TimeBlock] = []
        for block in freeBlocks {
            if let last = merged.last, block.startTime <= last.endTime {
                let newEndTime = max(last.endTime, block.endTime)
                merged[merged.count - 1].endTime = newEndTime
            } else {
                merged.append(block)
            }
        }
        
        var finalBlocks = editedBlocks.filter { $0.status != .free }
        finalBlocks.append(contentsOf: merged)
        
        withAnimation {
            self.editedBlocks = finalBlocks
        }
    }
    
    private func removeBlock(_ block: TimeBlock) {
        withAnimation {
            editedBlocks.removeAll { $0.id == block.id }
        }
    }

    private func isQuickFillActive(startHour: Int, endHour: Int) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)
        let qStart = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: startOfDay)!
        let qEnd = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: startOfDay)!
        
        return editedBlocks.contains { block in
            block.status == .free && block.startTime <= qStart && block.endTime >= qEnd
        }
    }
    
    private func saveAndDismiss() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let freeBlocks = editedBlocks.filter { $0.status == .free }.sorted { $0.startTime < $1.startTime }
        var finalBlocks: [TimeBlock] = []
        
        var currentTime = startOfDay
        
        for freeBlock in freeBlocks {
            if freeBlock.startTime > currentTime {
                finalBlocks.append(TimeBlock(startTime: currentTime, endTime: freeBlock.startTime, status: .busy))
            }
            finalBlocks.append(freeBlock)
            currentTime = freeBlock.endTime
        }
        
        if currentTime < endOfDay {
            finalBlocks.append(TimeBlock(startTime: currentTime, endTime: endOfDay, status: .busy))
        }
        
        var updatedDay = day
        updatedDay.timeBlocks = finalBlocks
        
        onSave(updatedDay)
        dismiss()
    }
}

struct DatePickerRow: View {
    let title: String
    let icon: String
    @Binding var selection: Date
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 20)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            DatePicker("", selection: $selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "en_US_POSIX")) // Force 12h/24h based on locale but usually ensures AM/PM in US
        }
    }
}

struct QuickFillButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .foregroundColor(isSelected ? .white : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? color : color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(color, lineWidth: isSelected ? 0 : 1.5)
            )
        }
    }
}
