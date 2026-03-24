// AppConfiguration.swift
// StarterApp
//
// Central place for environment-specific configuration values.
// In a production app, drive these from Info.plist build settings or
// a Secrets.xcconfig file (never commit secrets to source control).

import Foundation

enum AppConfiguration {

    // MARK: - Environment Detection

    enum Environment {
        case development
        case staging
        case production
    }

    /// Change this to switch environments, or drive it from a build flag.
    static let current: Environment = {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }()

    // MARK: - API

    static var apiBaseURL: String {
        switch current {
        case .development:  return "https://dev.api.example.com"
        case .staging:      return "https://staging.api.example.com"
        case .production:   return "https://api.example.com"
        }
    }

    /// API key / token — read from Info.plist in production.
    static var apiKey: String {
        Bundle.main.infoDictionary?["API_KEY"] as? String ?? ""
    }

    // MARK: - Feature Flags

    static var enableWatchSync: Bool { true }
    static var enableBiometrics: Bool { true }
}
