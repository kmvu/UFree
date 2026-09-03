//
//  DiscoveryCardView.swift
//  UFree
//
//  Created by Khang Vu on 04/28/26.
//

import AVFoundation
import SwiftUI

struct DiscoveryCardView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var viewModel: FriendsViewModel
    let userId: String

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    private var cardHeight: CGFloat {
        isRegularWidth ? 420 : 330
    }

    private var qrSize: CGFloat {
        isRegularWidth ? 220 : 160
    }

    var body: some View {
        ZStack {
            if viewModel.showQRScanner {
                scannerView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                myQRView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .animation(.easeInOut(duration: 0.4), value: viewModel.showQRScanner)
        .onAppear {
            // Share-first: show My QR by default; scanner is opt-in
            viewModel.showMyQRCard = true
            viewModel.showQRScanner = false
            viewModel.generateMyQRCode(from: userId)
        }
    }

    private var scannerView: some View {
        ZStack {
            if QRScannerCapability.isAvailable {
                QRScannerView(scannedCode: $viewModel.scannedCode)
                    .background(Color.black)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Camera scanning isn’t available on this device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .secondarySystemBackground))
            }

            VStack {
                Spacer()
                Button {
                    HapticManager.light()
                    viewModel.showQRScanner = false
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
                        .frame(width: qrSize, height: qrSize)
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

                if QRScannerCapability.isAvailable {
                    Button {
                        HapticManager.light()
                        viewModel.showQRScanner = true
                        viewModel.showMyQRCard = false
                    } label: {
                        Text("Scan a Friend's Code")
                            .font(.subheadline).bold()
                            .padding(.vertical, 10)
                            .padding(.horizontal, 24)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .foregroundColor(.primary)
                    }
                } else {
                    Text("Share your code — camera scanning isn’t available here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer(minLength: 24)
            }
            .padding()
        }
    }
}

enum QRScannerCapability {
    /// Soft-gate for Mac Designed for iPad / devices without a usable camera.
    static var isAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }
}
