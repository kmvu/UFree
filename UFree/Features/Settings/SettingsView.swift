//
//  SettingsView.swift
//  UFree
//
//  Created by Khang Vu on 17/06/26.
//

import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Display Name", text: $viewModel.displayName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .disabled(viewModel.isProcessing)
                }
                
                Section {
                    Button(action: {
                        Task {
                            await viewModel.saveProfile()
                        }
                    }) {
                        if viewModel.isProcessing {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isProcessing || viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isProcessing)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .onChange(of: viewModel.isSaveSuccessful) { _, success in
                if success {
                    dismiss()
                }
            }
            .task {
                await viewModel.loadInitialData()
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(
        authRepository: MockAuthRepository(),
        friendRepository: MockFriendRepository()
    ))
}
