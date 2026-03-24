// APIService.swift
// StarterApp
//
// Protocol-driven networking layer built on URLSession + async/await.
// Swap the concrete implementation in DIContainer for mocking in tests.

import Foundation

// MARK: - Protocol

protocol APIServiceProtocol {
    /// Performs a network request and decodes the response into type T.
    func request<T: Decodable>(_ endpoint: any APIEndpoint) async throws -> T

    /// Performs a request where no response body is expected (e.g. DELETE).
    func requestVoid(_ endpoint: any APIEndpoint) async throws

    /// Sets a global header applied to every request (e.g. Authorization token).
    func setGlobalHeader(value: String, forKey key: String)

    /// Removes a previously set global header.
    func removeGlobalHeader(forKey key: String)
}

// MARK: - Concrete Implementation

final class APIService: APIServiceProtocol {

    // MARK: - Dependencies

    private let session: URLSession
    private let decoder: JSONDecoder
    private var globalHeaders: [String: String] = [:]
    private let headersLock = NSLock()

    // MARK: - Init

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = {
            let d = JSONDecoder()
            d.keyDecodingStrategy = .convertFromSnakeCase
            d.dateDecodingStrategy = .iso8601
            return d
        }()
    ) {
        self.session = session
        self.decoder = decoder
    }

    // MARK: - APIServiceProtocol

    func request<T: Decodable>(_ endpoint: any APIEndpoint) async throws -> T {
        let data = try await performRequest(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    func requestVoid(_ endpoint: any APIEndpoint) async throws {
        _ = try await performRequest(endpoint)
    }

    func setGlobalHeader(value: String, forKey key: String) {
        headersLock.lock()
        defer { headersLock.unlock() }
        globalHeaders[key] = value
    }

    func removeGlobalHeader(forKey key: String) {
        headersLock.lock()
        defer { headersLock.unlock() }
        globalHeaders.removeValue(forKey: key)
    }

    // MARK: - Private Helpers

    private func performRequest(_ endpoint: any APIEndpoint) async throws -> Data {
        var urlRequest = try endpoint.asURLRequest()

        // Merge global headers (endpoint-specific headers take priority)
        let currentGlobals = headersLock.withLock { globalHeaders }

        currentGlobals.forEach { key, value in
            if urlRequest.value(forHTTPHeaderField: key) == nil {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.unknown(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw APIError.unauthorized
        case 400...499:
            throw APIError.requestFailed(statusCode: httpResponse.statusCode)
        case 500...599:
            let message = String(data: data, encoding: .utf8) ?? "Server error"
            throw APIError.serverError(message)
        default:
            throw APIError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Mock Implementation (for unit tests & SwiftUI previews)

#if DEBUG
final class MockAPIService: APIServiceProtocol {

    /// Set a stub result before calling request<T>.
    var stubbedResult: Any?
    var stubbedError: Error?
    private(set) var lastEndpoint: (any APIEndpoint)?

    func request<T: Decodable>(_ endpoint: any APIEndpoint) async throws -> T {
        lastEndpoint = endpoint
        if let error = stubbedError { throw error }
        guard let result = stubbedResult as? T else {
            throw APIError.noData
        }
        return result
    }

    func requestVoid(_ endpoint: any APIEndpoint) async throws {
        lastEndpoint = endpoint
        if let error = stubbedError { throw error }
    }

    func setGlobalHeader(value: String, forKey key: String) {}
    func removeGlobalHeader(forKey key: String) {}
}
#endif
