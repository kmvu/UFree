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
    var onFinished: (() -> Void)?
    /// Called after a successful wipe so the root session can drop immediately
    /// (auth-stream attach can lag behind `deleteAccount()`).
    var onAccountDeleted: (() -> Void)?
    @FocusState private var nameFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Display Name", text: $viewModel.displayName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .disabled(viewModel.isProcessing)
                        .focused($nameFieldFocused)
                }
                
                Section(
                    header: Text("Reminders"),
                    footer: Text("On-device weekend pings so you remember to check Who’s Free. No server push.")
                ) {
                    Toggle("Weekend planning reminder", isOn: Binding(
                        get: { viewModel.weekendRemindersEnabled },
                        set: { viewModel.setWeekendRemindersEnabled($0) }
                    ))
                    .disabled(viewModel.isProcessing)
                }

                Section {
                    Button(action: {
                        nameFieldFocused = false
                        Task {
                            await viewModel.saveProfile()
                        }
                    }) {
                        if viewModel.isProcessing && !viewModel.showDeleteConfirmation {
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

                Section(footer: Text("Deletes your UFree account, availability, friend requests, and discovery listings. Sign in with Apple is required to confirm.")) {
                    Button(role: .destructive) {
                        viewModel.requestAccountDeletion()
                    } label: {
                        if viewModel.isProcessing {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Delete Account")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.isProcessing)
                    .accessibilityIdentifier("settings.deleteAccount")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("settings.root")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        nameFieldFocused = false
                        if let onFinished {
                            onFinished()
                        } else {
                            dismiss()
                        }
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
            .alert("Delete Account?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.deletionConfirmed = true
                }
            } message: {
                Text("This permanently removes your account and cloud data. You will need to Sign in with Apple to confirm.")
            }
            .task(id: viewModel.deletionConfirmed) {
                guard viewModel.deletionConfirmed else { return }
                await viewModel.deleteAccount()
            }
            .onChange(of: viewModel.isSaveSuccessful) { _, success in
                if success {
                    finish()
                }
            }
            .onChange(of: viewModel.isDeleteSuccessful) { _, success in
                if success {
                    onAccountDeleted?()
                    finish()
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .task {
                await viewModel.loadInitialData()
            }
        }
    }

    private func finish() {
        nameFieldFocused = false
        if let onFinished {
            onFinished()
        } else {
            dismiss()
        }
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(
        authRepository: MockAuthRepository(),
        friendRepository: MockFriendRepository()
    ))
}
