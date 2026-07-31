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
    
    @State private var editor: DayDetailsEditor
    @State private var startTime: Date
    @State private var endTime: Date
    
    init(day: DayAvailability, onSave: @escaping (DayAvailability) -> Void) {
        self.day = day
        self.onSave = onSave
        
        let editor = DayDetailsEditor(day: day)
        self._editor = State(initialValue: editor)
        self._startTime = State(initialValue: editor.defaultStartTime())
        self._endTime = State(initialValue: editor.defaultEndTime())
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
                                QuickFillButton(title: "Morning", icon: "sunrise.fill", color: .orange, isSelected: editor.isQuickFillActive(.morning)) {
                                    applyQuickFill(.morning)
                                    scrollToWindows(proxy)
                                }
                                .frame(width: 100)
                                
                                QuickFillButton(title: "Afternoon", icon: "sun.max.fill", color: .yellow, isSelected: editor.isQuickFillActive(.afternoon)) {
                                    applyQuickFill(.afternoon)
                                    scrollToWindows(proxy)
                                }
                                .frame(width: 100)
                                
                                QuickFillButton(title: "Evening", icon: "moon.stars.fill", color: .purple, isSelected: editor.isQuickFillActive(.evening)) {
                                    applyQuickFill(.evening)
                                    scrollToWindows(proxy)
                                }
                                .frame(width: 100)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                    
                    Section(header: Text("Current Windows")) {
                        let freeBlocks = editor.freeBlocks
                        
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
        withAnimation {
            editor.addFreeWindow(from: startTime, to: endTime)
        }
        HapticManager.light()
    }
    
    private func applyQuickFill(_ quickFill: DayDetailsEditor.QuickFill) {
        var didAdd = false
        withAnimation {
            didAdd = editor.toggleQuickFill(quickFill)
        }
        
        if didAdd {
            HapticManager.success()
        } else {
            HapticManager.light()
        }
    }
    
    private func removeBlock(_ block: TimeBlock) {
        withAnimation {
            editor.removeBlock(id: block.id)
        }
    }
    
    private func saveAndDismiss() {
        onSave(editor.makeUpdatedDay(from: day))
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
