// UserRepository.swift
// StarterApp
//
// The Repository pattern coordinates between the APIService (remote source)
// and the DatabaseService (local cache). ViewModels interact only with this
// layer and never touch services directly.
//
// Pattern:
//   ViewModel → Repository → APIService  (network)
//                          → DatabaseService (cache)

import Foundation
import SwiftData

// MARK: - Protocol

protocol UserRepositoryProtocol {
    /// Fetches a user by ID. Returns the cached version immediately,
    /// then refreshes from the API in the background.
    func getUser(id: String) async throws -> UserDTO

    /// Fetches all locally cached users.
    func getCachedUsers() throws -> [UserDTO]

    /// Creates a new user on the server and caches the result.
    func createUser(name: String, email: String) async throws -> UserDTO

    /// Updates a user on the server and refreshes the local cache.
    func updateUser(id: String, name: String) async throws -> UserDTO

    /// Deletes a user from the server and removes from cache.
    func deleteUser(id: String) async throws

    /// Clears all locally cached users (e.g. on sign-out).
    func clearCache() throws
}

// MARK: - Concrete Implementation

final class UserRepository: UserRepositoryProtocol {

    // MARK: - Dependencies

    private let apiService: APIServiceProtocol
    private let databaseService: DatabaseServiceProtocol

    // MARK: - Init

    init(apiService: APIServiceProtocol, databaseService: DatabaseServiceProtocol) {
        self.apiService      = apiService
        self.databaseService = databaseService
    }

    // MARK: - UserRepositoryProtocol

    func getUser(id: String) async throws -> UserDTO {
        // 1. Try to serve from local cache first (fast path).
        if let cached = try? databaseService.fetch(
            UserModel.self,
            predicate: #Predicate { $0.id == id }
        ).first {
            // 2. Kick off a background refresh — caller gets cached data immediately.
            Task {
                try? await refreshUser(id: id)
            }
            return cached.toDTO()
        }

        // 3. No cache hit — go to the network.
        return try await refreshUser(id: id)
    }

    func getCachedUsers() throws -> [UserDTO] {
        try databaseService
            .fetch(UserModel.self, sortBy: [SortDescriptor(\.name)])
            .map { $0.toDTO() }
    }

    func createUser(name: String, email: String) async throws -> UserDTO {
        let dto: UserDTO = try await apiService.request(
            UserEndpoint.createUser(name: name, email: email)
        )
        let model = UserModel(from: dto)
        try databaseService.insert(model)
        return dto
    }

    func updateUser(id: String, name: String) async throws -> UserDTO {
        let dto: UserDTO = try await apiService.request(
            UserEndpoint.updateUser(id: id, name: name)
        )
        // Update local cache if present, otherwise insert.
        if let existing = try? databaseService.fetch(
            UserModel.self,
            predicate: #Predicate { $0.id == id }
        ).first {
            existing.update(from: dto)
            try databaseService.save()
        } else {
            try databaseService.insert(UserModel(from: dto))
        }
        return dto
    }

    func deleteUser(id: String) async throws {
        try await apiService.requestVoid(UserEndpoint.deleteUser(id: id))
        if let model = try? databaseService.fetch(
            UserModel.self,
            predicate: #Predicate { $0.id == id }
        ).first {
            try databaseService.delete(model)
        }
    }

    func clearCache() throws {
        let all = try databaseService.fetch(UserModel.self)
        for model in all {
            try databaseService.delete(model)
        }
    }

    // MARK: - Private Helpers

    @discardableResult
    private func refreshUser(id: String) async throws -> UserDTO {
        let dto: UserDTO = try await apiService.request(UserEndpoint.getUser(id: id))
        if let existing = try? databaseService.fetch(
            UserModel.self,
            predicate: #Predicate { $0.id == id }
        ).first {
            existing.update(from: dto)
            try databaseService.save()
        } else {
            try databaseService.insert(UserModel(from: dto))
        }
        return dto
    }
}

// MARK: - Mock Implementation (for unit tests & SwiftUI previews)

#if DEBUG
final class MockUserRepository: UserRepositoryProtocol {
    var stubbedUser: UserDTO?
    var stubbedUsers: [UserDTO] = []
    var stubbedError: Error?

    private(set) var lastGetID: String?
    private(set) var lastCreateName: String?
    private(set) var lastUpdateID: String?
    private(set) var lastDeleteID: String?
    private(set) var clearCacheCalled = false

    func getUser(id: String) async throws -> UserDTO {
        lastGetID = id
        if let error = stubbedError { throw error }
        return stubbedUser ?? .preview
    }

    func getCachedUsers() throws -> [UserDTO] {
        if let error = stubbedError { throw error }
        return stubbedUsers
    }

    func createUser(name: String, email: String) async throws -> UserDTO {
        lastCreateName = name
        if let error = stubbedError { throw error }
        return stubbedUser ?? UserDTO(id: UUID().uuidString, name: name, email: email,
                                      avatarURL: nil, createdAt: .now, updatedAt: .now)
    }

    func updateUser(id: String, name: String) async throws -> UserDTO {
        lastUpdateID = id
        if let error = stubbedError { throw error }
        return stubbedUser ?? .preview
    }

    func deleteUser(id: String) async throws {
        lastDeleteID = id
        if let error = stubbedError { throw error }
    }

    func clearCache() throws {
        clearCacheCalled = true
    }
}
#endif
