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
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                        .submitLabel(.go)
                        .onSubmit {
                            viewModel.loginTapped()
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(isNameFocused ? 0.5 : 0), lineWidth: 2)
                        )
                    
                    Text("This name will be visible to your friends.")
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
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Get Started")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.name.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isLoading || viewModel.name.isEmpty)
                .padding(.horizontal)
                
                Spacer()
                Spacer()
            }
            .padding()
        }
        .alert("Login Failed", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .onAppear {
            isNameFocused = true
        }
    }
}

// MARK: - Preview
#Preview {
    LoginView(viewModel: LoginViewModel(authRepository: MockAuthRepository()))
}
