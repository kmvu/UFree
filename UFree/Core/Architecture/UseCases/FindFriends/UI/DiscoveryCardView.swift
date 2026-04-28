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
                    .transition(.asymmetric(insertion: .flip, removal: .flip))
            } else {
                scannerView
                    .transition(.asymmetric(insertion: .flip, removal: .flip))
            }
        }
        .frame(height: 250)
        .cornerRadius(20)
        .shadow(radius: 5)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showMyQRCard)
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
            
            VStack(spacing: 12) {
                if let qrImage = viewModel.qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                
                Text("Your UFree Handshake")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button {
                    HapticManager.light()
                    viewModel.showMyQRCard = false
                } label: {
                    Text("Scan Code")
                        .font(.subheadline).bold()
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .foregroundColor(.primary)
                }
            }
            .padding()
        }
    }
}

extension AnyTransition {
    static var flip: AnyTransition {
        .modifier(
            active: FlipModifier(pct: 180),
            identity: FlipModifier(pct: 0)
        )
    }
}

struct FlipModifier: AnimatableModifier {
    var pct: Double
    
    var animatableData: Double {
        get { pct }
        set { pct = newValue }
    }
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(Angle(degrees: pct), axis: (x: 0, y: 1, z: 0))
    }
}
