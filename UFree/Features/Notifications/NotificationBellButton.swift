//
//  NotificationBellButton.swift
//  UFree
//
//  Created by Khang Vu on 08/01/26.
//

import SwiftUI

struct NotificationBellButton: View {
    @Binding var isPresented: Bool
    @Environment(\.notificationViewModel) var notificationViewModel
    @State private var showSheet = false
    
    var body: some View {
        Button {
            showSheet = true
        } label: {
            ZStack {
                Image(systemName: "bell.fill")
                    .font(.body)
                
                if let vm = notificationViewModel, vm.unreadCount > 0 {
                    Text("\(vm.unreadCount)")
                        .font(.caption2)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .sheet(isPresented: $showSheet) {
            if let vm = notificationViewModel {
                NotificationCenterView(viewModel: vm)
            }
        }
    }
}

extension EnvironmentValues {
    @Entry var notificationViewModel: NotificationViewModel? = nil
}
