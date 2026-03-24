// HomeViewModel.swift
// StarterApp
//
// Example ViewModel demonstrating how to wire all four services together
// in an MVVM pattern with async/await and Combine.

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {

    nonisolated let objectWillChange = ObservableObjectPublisher()

    // MARK: - Published State

    @Published private(set) var user: UserDTO?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var watchState: WatchState = WatchState()
    @Published private(set) var deviceInfo: DeviceInfo = DeviceInfo()

    // MARK: - Supporting Types

    struct DeviceInfo {
        var deviceID: String   = ""
        var osVersion: String  = ""
        var appVersion: String = ""
        var deviceModel: String = ""
        var deviceName: String = ""
    }

    // MARK: - Dependencies

    private let userRepository: UserRepositoryProtocol
    private let deviceService: DeviceServiceProtocol
    private let watchConnectorService: WatchConnectorServiceProtocol

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(container: DIContainer) {
        self.userRepository         = container.userRepository
        self.deviceService          = container.deviceService
        self.watchConnectorService  = container.watchConnectorService

        bindWatchState()
        loadDeviceInfo()
    }

    // MARK: - Intents (called from the View)

    func loadUser(id: String) {
        Task {
            await perform {
                self.user = try await self.userRepository.getUser(id: id)
            }
        }
    }

    func createUser(name: String, email: String) {
        Task {
            await perform {
                self.user = try await self.userRepository.createUser(name: name, email: email)
            }
        }
    }

    func pingWatch() {
        do {
            try watchConnectorService.sendMessage(.ping, replyHandler: { reply in
                print("[HomeViewModel] Watch replied: \(reply)")
            })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncUserToWatch() {
        guard let user else { return }
        do {
            try watchConnectorService.updateApplicationContext([
                "userName":  user.name,
                "userEmail": user.email,
                "lastSync":  ISO8601DateFormatter().string(from: .now)
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestPushPermission() {
        Task {
            let granted = await deviceService.requestPushNotificationPermission()
            if !granted {
                self.errorMessage = "Push notification permission was denied."
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Helpers

    private func loadDeviceInfo() {
        deviceInfo = DeviceInfo(
            deviceID:    deviceService.deviceID,
            osVersion:   deviceService.osVersion,
            appVersion:  deviceService.appVersion,
            deviceModel: deviceService.deviceModel,
            deviceName:  deviceService.deviceName
        )
    }

    private func bindWatchState() {
        watchConnectorService.watchStatePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.watchState, on: self)
            .store(in: &cancellables)

        watchConnectorService.receivedMessagePublisher
            .receive(on: DispatchQueue.main)
            .sink { message in
                switch message {
                case .ping:
                    print("[HomeViewModel] Watch sent a ping.")
                case .syncData(let data):
                    print("[HomeViewModel] Watch synced data: \(data)")
                case .custom(let key, let payload):
                    print("[HomeViewModel] Watch custom message '\(key)': \(payload)")
                }
            }
            .store(in: &cancellables)
    }

    /// Wraps an async throwing closure with loading/error state management.
    private func perform(_ action: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
