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
                        DatePickerRow(title: "Start", selection: $startTime)
                        DatePickerRow(title: "End", selection: $endTime)
                        
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
                        .listRowBackground(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                    }
                    
                    Section(header: Text("Quick Fills")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                QuickFillButton(title: "Morning", icon: "sunrise.fill", color: .orange) {
                                    applyQuickFill(startHour: 9, endHour: 12)
                                    scrollToWindows(proxy)
                                }
                                .frame(width: 100)
                                
                                QuickFillButton(title: "Afternoon", icon: "sun.max.fill", color: .yellow) {
                                    applyQuickFill(startHour: 12, endHour: 17)
                                    scrollToWindows(proxy)
                                }
                                .frame(width: 100)
                                
                                QuickFillButton(title: "Evening", icon: "moon.stars.fill", color: .purple) {
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
        
        let newBlock = TimeBlock(startTime: qStart, endTime: qEnd, status: .free)
        mergeAndAddBlock(newBlock)
        HapticManager.success()
    }
    
    private func mergeAndAddBlock(_ newBlock: TimeBlock) {
        var freeBlocks = editedBlocks.filter { $0.status == .free }
        freeBlocks.append(newBlock)
        
        // Sort by start time
        freeBlocks.sort { $0.startTime < $1.startTime }
        
        var merged: [TimeBlock] = []
        for block in freeBlocks {
            if let last = merged.last, block.startTime <= last.endTime {
                // Overlap or adjacency detected, merge them
                let newEndTime = max(last.endTime, block.endTime)
                merged[merged.count - 1].endTime = newEndTime
            } else {
                merged.append(block)
            }
        }
        
        withAnimation {
            self.editedBlocks = merged
        }
    }
    
    private func removeBlock(_ block: TimeBlock) {
        withAnimation {
            editedBlocks.removeAll { $0.id == block.id }
        }
    }
    
    private func saveAndDismiss() {
        // Ensure 24-hour coverage by filling gaps with Busy blocks
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let freeBlocks = editedBlocks.filter { $0.status == .free }.sorted { $0.startTime < $1.startTime }
        var finalBlocks: [TimeBlock] = []
        
        var currentTime = startOfDay
        
        for freeBlock in freeBlocks {
            // Fill gap before free block with busy
            if freeBlock.startTime > currentTime {
                finalBlocks.append(TimeBlock(startTime: currentTime, endTime: freeBlock.startTime, status: .busy))
            }
            finalBlocks.append(freeBlock)
            currentTime = freeBlock.endTime
        }
        
        // Fill remaining time after last free block with busy
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
    @Binding var selection: Date
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            DatePicker(title, selection: $selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Tapping the row doesn't automatically focus the DatePicker numbers
            // but in a List/Form this layout is the most accessible for tapping the picker itself
        }
    }
}

struct QuickFillButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(10)
        }
    }
}
