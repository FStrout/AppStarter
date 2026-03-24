// APIError.swift
// StarterApp
//
// Defines all errors that can be thrown by the API layer.

import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case noData
    case decodingFailed(Error)
    case encodingFailed(Error)
    case unauthorized
    case serverError(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is malformed or invalid."
        case .requestFailed(let code):
            return "Request failed with HTTP status code \(code)."
        case .noData:
            return "The server returned no data."
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode request body: \(error.localizedDescription)"
        case .unauthorized:
            return "Authentication required. Please log in again."
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}
