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
    @Environment(\.colorScheme) private var colorScheme
    
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
                    
                    TextField("Phone Number (optional)", text: $viewModel.phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    
                    Text("Sign in with Apple is your account. Phone is optional so friends can find you — we store a one-way hash, not your number. Someone else could claim the same hash first until phone verification ships.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
                .padding(.horizontal)
                
                // 3. Sign in with Apple
                Button(action: {
                    viewModel.loginTapped()
                }) {
                    HStack(spacing: 10) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(colorScheme == .dark ? .black : .white)
                        } else {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Sign in with Apple")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                    .background(colorScheme == .dark ? Color.white : Color.black)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isLoading || viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                .padding(.horizontal)
                
                Spacer()
                Spacer()
                
                #if DEBUG
                // Development Tools — Simulator cannot use SiwA reliably.
                VStack(spacing: 12) {
                    Divider()
                        .padding(.vertical, 8)
                    
                    Text("DEVELOPER TOOLS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("Simulator personas (anonymous auth)")
                        .font(.caption2)
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
