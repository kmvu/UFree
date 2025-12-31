//
//  LoginView.swift
//  UFree
//
//  Created by Khang Vu on 31/12/25.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: RootViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("UFree")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Share your weekly availability")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Button(action: {
                viewModel.signInAnonymously()
            }) {
                if viewModel.isSigningIn {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .disabled(viewModel.isSigningIn)
            
            if let errorMessage = viewModel.errorMessage {
                Text("Error: \(errorMessage)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
    }
}

#Preview {
    LoginView(viewModel: RootViewModel(authRepository: MockAuthRepository()))
}
