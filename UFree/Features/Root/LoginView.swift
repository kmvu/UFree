//
//  LoginView.swift
//  UFree
//
//  Created by Khang Vu on 31/12/25.
//

import SwiftUI

struct LoginView: View {
    @StateObject var viewModel: LoginViewModel
    @FocusState private var isNameFocused: Bool
    
    var body: some View {
        ZStack {
            // Background Color
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // 1. Logo / Branding
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue, .green)
                        .symbolRenderingMode(.palette)
                    
                    Text("UFree")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    
                    Text("Sync your free time with friends.")
                        .font(UFreeType.heroBody)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 20)
                
                // 2. Input Section
                VStack(spacing: 16) {
                    TextField("Your Name (e.g. Alex)", text: $viewModel.name)
                        .textContentType(.givenName)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .focused($isNameFocused)
                        .submitLabel(.next)
                    
                    TextField("Phone Number", text: $viewModel.phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .submitLabel(.go)
                        .onSubmit {
                            viewModel.loginTapped()
                        }
                    
                    Text("Your name and phone number allow friends to find you. Your phone number is stored as a secure hash for privacy.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
                .padding(.horizontal)
                
                // 3. Action Button
                Button(action: {
                    viewModel.loginTapped()
                }) {
                    HStack(spacing: 10) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Get Started")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .ufreePrimaryButton(
                    isEnabled: !(viewModel.isLoading || viewModel.name.isEmpty || viewModel.phoneNumber.isEmpty)
                )
                .disabled(viewModel.isLoading || viewModel.name.isEmpty || viewModel.phoneNumber.isEmpty)
                .padding(.horizontal)
                
                Spacer()
                Spacer()
                
                #if DEBUG
                // Development Tools
                VStack(spacing: 12) {
                    Divider()
                        .padding(.vertical, 8)
                    
                    Text("DEVELOPER TOOLS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 10) {
                        Button("User 1") {
                            Task {
                                await viewModel.loginAsTestUser(index: 0)
                            }
                        }
                        .ufreeCompactButton(prominent: false)
                        
                        Button("User 2") {
                            Task {
                                await viewModel.loginAsTestUser(index: 1)
                            }
                        }
                        .ufreeCompactButton(prominent: false)
                        
                        Button("User 3") {
                            Task {
                                await viewModel.loginAsTestUser(index: 2)
                            }
                        }
                        .ufreeCompactButton(prominent: false)
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
                .padding()
                #endif
            }
            .padding()
            .adaptiveContentWidth(AdaptiveLayout.formContentMaxWidth)
        }
        .alert("Login Failed", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .onAppear {
            // Don't fight the keyboard against an already-presented error alert — UIKit
            // rejects the second presentation ("while a presentation is in progress") and
            // on the iOS 26.2 simulator that path corrupts allocator state.
            guard !viewModel.showError else { return }
            isNameFocused = true
        }
    }
}

// MARK: - Preview
#Preview {
    LoginView(viewModel: LoginViewModel(authRepository: MockAuthRepository()))
}
