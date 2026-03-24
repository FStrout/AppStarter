// UserModel.swift
// StarterApp
//
// SwiftData persistent model for a User.
// This serves as the canonical example — add fields and relationships
// as needed for your domain.

import Foundation
import SwiftData

// MARK: - Persistent Model

@Model
final class UserModel {

    // MARK: Stored Properties

    /// Stable unique identifier (matches the server-side ID).
    @Attribute(.unique) var id: String

    var name: String
    var email: String
    var createdAt: Date
    var updatedAt: Date

    /// Optional URL string for a remote profile image.
    var avatarURL: String?

    // MARK: Init

    init(
        id: String = UUID().uuidString,
        name: String,
        email: String,
        avatarURL: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id        = id
        self.name      = name
        self.email     = email
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - DTO (Data Transfer Object)

/// Plain struct returned by the API. Decoupled from SwiftData so the
/// network layer has no persistence dependency.
struct UserDTO: Codable, Equatable {
    let id: String
    let name: String
    let email: String
    let avatarURL: String?
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Mapping Helpers

extension UserModel {
    /// Creates (or updates) a SwiftData model from a DTO.
    convenience init(from dto: UserDTO) {
        self.init(
            id:        dto.id,
            name:      dto.name,
            email:     dto.email,
            avatarURL: dto.avatarURL,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    func update(from dto: UserDTO) {
        self.name      = dto.name
        self.email     = dto.email
        self.avatarURL = dto.avatarURL
        self.updatedAt = dto.updatedAt
    }

    func toDTO() -> UserDTO {
        UserDTO(
            id:        id,
            name:      name,
            email:     email,
            avatarURL: avatarURL,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension UserDTO {
    static let preview = UserDTO(
        id:        "user-001",
        name:      "Fred Strout",
        email:     "fred@example.com",
        avatarURL: nil,
        createdAt: .now,
        updatedAt: .now
    )
}
#endif
