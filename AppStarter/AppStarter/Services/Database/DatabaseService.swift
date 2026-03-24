// DatabaseService.swift
// StarterApp
//
// Protocol-driven persistence layer built on SwiftData (iOS 17+).
// The protocol makes the layer fully mockable for unit tests.

import Foundation
import SwiftData

// MARK: - Protocol

protocol DatabaseServiceProtocol {
    /// Inserts a new model into the store and saves.
    func insert<T: PersistentModel>(_ model: T) throws

    /// Fetches all instances of a model type, with an optional predicate and sort.
    func fetch<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>?,
        sortBy: [SortDescriptor<T>]
    ) throws -> [T]

    /// Deletes a model from the store and saves.
    func delete<T: PersistentModel>(_ model: T) throws

    /// Persists any pending changes to disk.
    func save() throws
}

// Convenience default arguments so callers don't need to specify them every time.
extension DatabaseServiceProtocol {
    func fetch<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>? = nil,
        sortBy: [SortDescriptor<T>] = []
    ) throws -> [T] {
        try fetch(type, predicate: predicate, sortBy: sortBy)
    }
}

// MARK: - Concrete Implementation

/// Wraps a SwiftData `ModelContext` to provide a clean, testable interface.
/// Initialise with the shared `ModelContainer` from `DIContainer`.
final class DatabaseService: DatabaseServiceProtocol {

    // MARK: - Properties

    private let context: ModelContext

    // MARK: - Init

    /// - Parameter container: The app's shared `ModelContainer`.
    init(container: ModelContainer) {
        // Create a dedicated context for this service. Using `@MainActor`
        // contexts here keeps SwiftData thread-safety simple; for background
        // work, create a separate context inside a detached Task.
        self.context = ModelContext(container)
        self.context.autosaveEnabled = false // We control saves explicitly.
    }

    // MARK: - DatabaseServiceProtocol

    func insert<T: PersistentModel>(_ model: T) throws {
        context.insert(model)
        try save()
    }

    func fetch<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>? = nil,
        sortBy: [SortDescriptor<T>] = []
    ) throws -> [T] {
        let descriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sortBy)
        return try context.fetch(descriptor)
    }

    func delete<T: PersistentModel>(_ model: T) throws {
        context.delete(model)
        try save()
    }

    func save() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}

// MARK: - ModelContainer Setup

extension ModelContainer {
    /// Creates the app's shared `ModelContainer` with all registered SwiftData models.
    /// Add new `PersistentModel` types to the `schema` array as the app grows.
    static func makeAppContainer() throws -> ModelContainer {
        let schema = Schema([
            UserModel.self
            // Add more model types here, e.g.: PostModel.self, SettingsModel.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false   // Set `true` for unit tests
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// In-memory container used in unit tests and SwiftUI previews.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([UserModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

// MARK: - Mock Implementation (for unit tests & SwiftUI previews)

#if DEBUG
final class MockDatabaseService: DatabaseServiceProtocol {
    private var store: [String: Any] = [:]

    var insertedModels: [Any] = []
    var deletedModels: [Any] = []
    var saveCallCount = 0
    var shouldThrowOnSave = false

    func insert<T: PersistentModel>(_ model: T) throws {
        insertedModels.append(model)
    }

    func fetch<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>?,
        sortBy: [SortDescriptor<T>]
    ) throws -> [T] {
        // Return whatever has been inserted (basic mock — extend per test).
        return insertedModels.compactMap { $0 as? T }
    }

    func delete<T: PersistentModel>(_ model: T) throws {
        deletedModels.append(model)
        insertedModels.removeAll { ($0 as AnyObject) === (model as AnyObject) }
    }

    func save() throws {
        saveCallCount += 1
        if shouldThrowOnSave {
            throw DatabaseError.saveFailed("Mock save failure")
        }
    }
}

enum DatabaseError: LocalizedError {
    case saveFailed(String)
    var errorDescription: String? {
        switch self {
        case .saveFailed(let msg): return "Save failed: \(msg)"
        }
    }
}
#endif
