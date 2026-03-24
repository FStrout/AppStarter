// DIContainer.swift
// StarterApp
//
// Dependency Injection container. All services and repositories are
// created here and injected into ViewModels.
//
// Usage (SwiftUI):
//   @StateObject private var vm = HomeViewModel(container: .shared)
//
// Usage (Unit Tests):
//   let container = DIContainer(testing: true)
//   // container has mock services automatically

import Combine
import Foundation
import SwiftData

@MainActor
final class DIContainer: ObservableObject {

    nonisolated let objectWillChange = ObservableObjectPublisher()

    // MARK: - Shared Instance

    static let shared = DIContainer()

    // MARK: - Services (lazily initialised)

    let apiService: APIServiceProtocol
    let databaseService: DatabaseServiceProtocol
    let deviceService: DeviceServiceProtocol
    let watchConnectorService: WatchConnectorServiceProtocol

    // MARK: - Repositories

    lazy var userRepository: UserRepositoryProtocol = UserRepository(
        apiService: apiService,
        databaseService: databaseService
    )

    // MARK: - Designated Init

    init(
        apiService: APIServiceProtocol,
        databaseService: DatabaseServiceProtocol,
        deviceService: DeviceServiceProtocol,
        watchConnectorService: WatchConnectorServiceProtocol
    ) {
        self.apiService = apiService
        self.databaseService = databaseService
        self.deviceService = deviceService
        self.watchConnectorService = watchConnectorService
    }

    // MARK: - Init (production)

    convenience init() {
        let api = APIService()
        if !AppConfiguration.apiKey.isEmpty {
            api.setGlobalHeader(value: AppConfiguration.apiKey, forKey: "X-API-Key")
        }

        let modelContainer: ModelContainer
        do {
            modelContainer = try ModelContainer.makeAppContainer()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        self.init(
            apiService: api,
            databaseService: DatabaseService(container: modelContainer),
            deviceService: DeviceService(),
            watchConnectorService: WatchConnectorService.shared
        )
    }

    // MARK: - Init (unit tests / previews)

    #if DEBUG
    /// Creates a container where all services are replaced with mocks,
    /// and the database is in-memory only.
    convenience init(testing: Bool) {
        guard testing else {
            self.init()
            return
        }

        let modelContainer: ModelContainer
        do {
            modelContainer = try ModelContainer.makeInMemoryContainer()
        } catch {
            fatalError("Failed to create in-memory ModelContainer: \(error)")
        }

        self.init(
            apiService: MockAPIService(),
            databaseService: DatabaseService(container: modelContainer),
            deviceService: MockDeviceService(),
            watchConnectorService: MockWatchConnectorService()
        )
    }

    static var preview: DIContainer { DIContainer(testing: true) }
    #endif
}
