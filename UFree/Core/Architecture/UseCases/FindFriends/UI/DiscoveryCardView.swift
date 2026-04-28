//
//  DiscoveryCardView.swift
//  UFree
//
//  Created by Khang Vu on 04/28/26.
//

import SwiftUI

struct DiscoveryCardView: View {
    @ObservedObject var viewModel: FriendsViewModel
    let userId: String
    
    var body: some View {
        ZStack {
            if viewModel.showMyQRCard {
                myQRView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                scannerView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .frame(height: 330)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .animation(.easeInOut(duration: 0.4), value: viewModel.showMyQRCard)
    }
    
    private var scannerView: some View {
        ZStack {
            QRScannerView(scannedCode: $viewModel.scannedCode)
                .background(Color.black)
            
            VStack {
                Spacer()
                Button {
                    HapticManager.light()
                    viewModel.generateMyQRCode(from: userId)
                    viewModel.showMyQRCard = true
                } label: {
                    Text("Show My Code")
                        .font(.subheadline).bold()
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .foregroundColor(.primary)
                }
                .padding(.bottom, 20)
            }
        }
    }
    
    private var myQRView: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                
                if let qrImage = viewModel.qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                
                Text("Your UFree Handshake")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                
                Spacer(minLength: 16)
                
                Button {
                    HapticManager.light()
                    viewModel.showMyQRCard = false
                } label: {
                    Text("Scan Code")
                        .font(.subheadline).bold()
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .foregroundColor(.primary)
                }
                
                Spacer(minLength: 24)
            }
            .padding()
        }
    }
}
