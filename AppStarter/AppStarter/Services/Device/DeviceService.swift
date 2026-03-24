// DeviceService.swift
// StarterApp
//
// Provides device-level information and capabilities:
// unique device ID, OS/app version strings, push notification permission,
// and biometric authentication.

import Foundation
import UIKit
import UserNotifications
import LocalAuthentication

// MARK: - Protocol

protocol DeviceServiceProtocol {

    // MARK: Identity & Versioning

    /// A stable, vendor-scoped UUID for this device. Uses
    /// `UIDevice.identifierForVendor`, falling back to a UUID stored
    /// in the Keychain so it survives app reinstalls.
    var deviceID: String { get }

    /// e.g. "18.2.1"
    var osVersion: String { get }

    /// e.g. "1.0.0"
    var appVersion: String { get }

    /// e.g. "1"
    var buildNumber: String { get }

    /// e.g. "iPhone16,2"
    var deviceModel: String { get }

    /// Human-readable device name set by the user, e.g. "Fred's iPhone"
    var deviceName: String { get }

    // MARK: Push Notifications

    /// Returns the current authorisation status without prompting.
    func pushNotificationStatus() async -> UNAuthorizationStatus

    /// Requests authorisation for alerts, sounds, and badges.
    /// Returns `true` if the user grants permission.
    @discardableResult
    func requestPushNotificationPermission() async -> Bool

    // MARK: Biometrics

    /// Whether Face ID / Touch ID is available on this device.
    var isBiometricAvailable: Bool { get }

    /// The type of biometrics available (.faceID, .touchID, or .none).
    var biometricType: LABiometryType { get }

    /// Prompts the user to authenticate with biometrics or passcode.
    /// - Parameter reason: Localised string shown in the prompt.
    func authenticateWithBiometrics(reason: String) async throws -> Bool
}

// MARK: - Concrete Implementation

final class DeviceService: DeviceServiceProtocol {

    // MARK: - Identity & Versioning

    var deviceID: String {
        // Prefer UIDevice.identifierForVendor; it resets only on full erase.
        UIDevice.current.identifierForVendor?.uuidString ?? keychainDeviceID()
    }

    var osVersion: String {
        UIDevice.current.systemVersion
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? UIDevice.current.model
            }
        }
    }

    var deviceName: String {
        UIDevice.current.name
    }

    // MARK: - Push Notifications

    func pushNotificationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    func requestPushNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Biometrics

    var isBiometricAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    func authenticateWithBiometrics(reason: String) async throws -> Bool {
        let context = LAContext()
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }

    // MARK: - Private: Keychain Device ID Fallback

    private let keychainService = "com.starterapp.deviceID"
    private let keychainAccount = "deviceUUID"

    private func keychainDeviceID() -> String {
        // Attempt to read existing UUID from Keychain.
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      keychainService,
            kSecAttrAccount:      keychainAccount,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let uuidString = String(data: data, encoding: .utf8) {
            return uuidString
        }

        // Generate and persist a new UUID.
        let newUUID = UUID().uuidString
        let data = Data(newUUID.utf8)
        let addQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecValueData:   data
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
        return newUUID
    }
}

// MARK: - Mock Implementation (for unit tests & SwiftUI previews)

#if DEBUG
final class MockDeviceService: DeviceServiceProtocol {
    var deviceID: String = "MOCK-DEVICE-UUID"
    var osVersion: String = "17.0"
    var appVersion: String = "1.0.0"
    var buildNumber: String = "1"
    var deviceModel: String = "iPhone16,2"
    var deviceName: String = "Simulator"
    var isBiometricAvailable: Bool = true
    var biometricType: LABiometryType = .faceID

    var stubbedPushStatus: UNAuthorizationStatus = .notDetermined
    var stubbedPushPermissionResult: Bool = true
    var stubbedBiometricResult: Bool = true
    var stubbedBiometricError: Error? = nil

    func pushNotificationStatus() async -> UNAuthorizationStatus { stubbedPushStatus }
    func requestPushNotificationPermission() async -> Bool { stubbedPushPermissionResult }
    func authenticateWithBiometrics(reason: String) async throws -> Bool {
        if let error = stubbedBiometricError { throw error }
        return stubbedBiometricResult
    }
}
#endif
