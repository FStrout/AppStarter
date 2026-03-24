// HomeView.swift
// StarterApp
//
// Example SwiftUI view that exercises all four services via HomeViewModel.

import SwiftUI

struct HomeView: View {

    @StateObject var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            List {
                deviceSection
                watchSection
                userSection
            }
            .navigationTitle("Starter App")
            .toolbar {
                if viewModel.isLoading {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                // Load an example user on appear. Replace "user-001" with a
                // real ID from your auth flow or deep link.
                viewModel.loadUser(id: "user-001")
            }
        }
    }

    // MARK: - Sections

    private var deviceSection: some View {
        Section("Device Info") {
            LabeledContent("Device ID", value: viewModel.deviceInfo.deviceID)
            LabeledContent("Model",     value: viewModel.deviceInfo.deviceModel)
            LabeledContent("iOS",       value: viewModel.deviceInfo.osVersion)
            LabeledContent("App",       value: viewModel.deviceInfo.appVersion)
            LabeledContent("Name",      value: viewModel.deviceInfo.deviceName)

            Button("Request Push Permission") {
                viewModel.requestPushPermission()
            }
        }
    }

    private var watchSection: some View {
        Section("Apple Watch") {
            LabeledContent("Paired",     value: viewModel.watchState.isPaired     ? "Yes" : "No")
            LabeledContent("App Installed", value: viewModel.watchState.isWatchAppInstalled ? "Yes" : "No")
            LabeledContent("Reachable",  value: viewModel.watchState.isReachable  ? "Yes" : "No")

            Button("Ping Watch") {
                viewModel.pingWatch()
            }
            .disabled(!viewModel.watchState.isReachable)

            Button("Sync User to Watch") {
                viewModel.syncUserToWatch()
            }
            .disabled(viewModel.user == nil || !viewModel.watchState.isPaired)
        }
    }

    private var userSection: some View {
        Section("User (API + Database)") {
            if let user = viewModel.user {
                LabeledContent("Name",  value: user.name)
                LabeledContent("Email", value: user.email)
                LabeledContent("ID",    value: user.id)
            } else if viewModel.isLoading {
                HStack {
                    ProgressView()
                    Text("Loading user…").foregroundStyle(.secondary)
                }
            } else {
                Text("No user loaded.").foregroundStyle(.secondary)
            }

            Button("Create Example User") {
                viewModel.createUser(name: "Jane Appleseed", email: "jane@example.com")
            }
        }
    }
}

// MARK: - Previews

#Preview {
    HomeView(viewModel: HomeViewModel(container: .preview))
}
