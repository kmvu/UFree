//
//  StatusBannerView.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import SwiftUI

struct StatusBannerView: View {
    @StateObject private var viewModel = StatusBannerViewModel()

    var body: some View {
        Button(action: viewModel.cycleStatus) {
            HStack(spacing: 16) {
                Image(systemName: viewModel.currentStatus.iconName)
                    .font(.system(size: 26))
                    .foregroundColor(.white)
                    .id("icon-\(viewModel.currentStatus)")
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))

                VStack(alignment: .leading, spacing: 2) {
                    ZStack(alignment: .leading) {
                        Text(viewModel.currentStatus.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .id("title-\(viewModel.currentStatus)")
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                )
                            )
                    }
                    .clipped()
                    .frame(height: 26)

                    Text(viewModel.currentStatus.subtitle)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(
                LinearGradient(
                    colors: viewModel.currentStatus.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .animation(.easeOut(duration: 0.5), value: viewModel.currentStatus)
            )
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    .opacity(viewModel.isProcessing ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isProcessing)
            )
        }
        .buttonStyle(NoInteractionButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .disabled(viewModel.isProcessing)
    }
}

#Preview {
    StatusBannerView()
}
