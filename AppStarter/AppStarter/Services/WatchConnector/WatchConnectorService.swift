// WatchConnectorService.swift
// StarterApp
//
// Bi-directional communication between the iOS app and a paired Apple Watch.
// Built on WatchConnectivity (WCSession). Remember to:
//  1. Add the WatchConnectivity framework to your Xcode target.
//  2. Create a matching WKExtensionDelegate / App on the watchOS side.
//  3. Call `WatchConnectorService.shared.activate()` early in AppDelegate /
//     the @main App struct.

import Foundation
import WatchConnectivity
import Combine

// MARK: - Message Types

/// A strongly-typed wrapper around the raw [String: Any] dictionaries
/// that WCSession requires. Extend this enum for your own message types.
enum WatchMessage {
    case ping
    case syncData([String: Any])
    case custom(key: String, payload: [String: Any])

    var dictionary: [String: Any] {
        switch self {
        case .ping:
            return ["type": "ping"]
        case .syncData(let data):
            var dict = data
            dict["type"] = "syncData"
            return dict
        case .custom(let key, let payload):
            var dict = payload
            dict["type"] = key
            return dict
        }
    }

    static func from(_ dictionary: [String: Any]) -> WatchMessage {
        switch dictionary["type"] as? String {
        case "ping":     return .ping
        case "syncData": return .syncData(dictionary)
        default:
            let key = dictionary["type"] as? String ?? "unknown"
            return .custom(key: key, payload: dictionary)
        }
    }
}

// MARK: - Watch State

struct WatchState {
    var isPaired: Bool = false
    var isWatchAppInstalled: Bool = false
    var isReachable: Bool = false
    var isComplicationEnabled: Bool = false
    var activationState: WCSessionActivationState = .notActivated
}

// MARK: - Protocol

protocol WatchConnectorServiceProtocol: AnyObject {

    /// Observable state of the paired Watch.
    var watchStatePublisher: AnyPublisher<WatchState, Never> { get }

    /// Current watch state snapshot.
    var watchState: WatchState { get }

    /// Activates the WCSession. Call once at app launch.
    func activate()

    /// Sends a real-time interactive message. The Watch must be reachable.
    /// - Parameters:
    ///   - message: The message to send.
    ///   - reply: Optional async reply handler.
    func sendMessage(
        _ message: WatchMessage,
        replyHandler: (([String: Any]) -> Void)?
    ) throws

    /// Updates the Application Context — the Watch receives this when it next wakes.
    /// Only the most recent context is delivered; previous ones are overwritten.
    func updateApplicationContext(_ context: [String: Any]) throws

    /// Transfers user info in a queue — every call is delivered in order.
    func transferUserInfo(_ userInfo: [String: Any])

    /// Publishes messages received from the Watch.
    var receivedMessagePublisher: AnyPublisher<WatchMessage, Never> { get }
}

// MARK: - Watch Connector Errors

enum WatchConnectorError: LocalizedError {
    case sessionNotSupported
    case sessionNotActivated
    case watchNotReachable
    case watchAppNotInstalled
    case watchNotPaired

    var errorDescription: String? {
        switch self {
        case .sessionNotSupported:   return "WatchConnectivity is not supported on this device."
        case .sessionNotActivated:   return "WCSession has not been activated yet."
        case .watchNotReachable:     return "Apple Watch is not currently reachable."
        case .watchAppNotInstalled:  return "The Watch app is not installed."
        case .watchNotPaired:        return "No Apple Watch is paired with this iPhone."
        }
    }
}

// MARK: - Concrete Implementation

/// Thread-safe WCSession wrapper. Conforms to `WCSessionDelegate`.
/// The service owns its own `WCSessionDelegate` conformance so the
/// caller's classes stay lean.
final class WatchConnectorService: NSObject, WatchConnectorServiceProtocol {

    // MARK: - Singleton (optional — you can inject via DIContainer instead)

    static let shared = WatchConnectorService()

    // MARK: - Private State

    private var session: WCSession?
    private let watchStateSubject = CurrentValueSubject<WatchState, Never>(WatchState())
    private let receivedMessageSubject = PassthroughSubject<WatchMessage, Never>()

    // MARK: - Public Publishers

    var watchStatePublisher: AnyPublisher<WatchState, Never> {
        watchStateSubject.eraseToAnyPublisher()
    }

    var receivedMessagePublisher: AnyPublisher<WatchMessage, Never> {
        receivedMessageSubject.eraseToAnyPublisher()
    }

    var watchState: WatchState {
        watchStateSubject.value
    }

    // MARK: - Init

    override init() {
        super.init()
    }

    // MARK: - WatchConnectorServiceProtocol

    func activate() {
        guard WCSession.isSupported() else {
            print("[WatchConnector] WCSession is not supported on this device.")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    func sendMessage(
        _ message: WatchMessage,
        replyHandler: (([String: Any]) -> Void)? = nil
    ) throws {
        try ensureReachable()
        session?.sendMessage(
            message.dictionary,
            replyHandler: replyHandler,
            errorHandler: { error in
                print("[WatchConnector] sendMessage error: \(error.localizedDescription)")
            }
        )
    }

    func updateApplicationContext(_ context: [String: Any]) throws {
        guard let session, session.activationState == .activated else {
            throw WatchConnectorError.sessionNotActivated
        }
        try session.updateApplicationContext(context)
    }

    func transferUserInfo(_ userInfo: [String: Any]) {
        session?.transferUserInfo(userInfo)
    }

    // MARK: - Private Helpers

    private func ensureReachable() throws {
        guard WCSession.isSupported() else { throw WatchConnectorError.sessionNotSupported }
        guard let session, session.activationState == .activated else {
            throw WatchConnectorError.sessionNotActivated
        }
        guard session.isPaired else { throw WatchConnectorError.watchNotPaired }
        guard session.isWatchAppInstalled else { throw WatchConnectorError.watchAppNotInstalled }
        guard session.isReachable else { throw WatchConnectorError.watchNotReachable }
    }

    private func refreshState() {
        guard let session else { return }
        var state = WatchState()
        state.activationState    = session.activationState
        state.isPaired           = session.isPaired
        state.isWatchAppInstalled = session.isWatchAppInstalled
        state.isReachable        = session.isReachable
        state.isComplicationEnabled = session.isComplicationEnabled
        watchStateSubject.send(state)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectorService: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("[WatchConnector] Activation error: \(error.localizedDescription)")
        }
        refreshState()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        refreshState()
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Required on iOS — reactivate to support Watch switching.
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        refreshState()
    }

    // Receive interactive messages from the Watch.
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let watchMessage = WatchMessage.from(message)
        receivedMessageSubject.send(watchMessage)
        // Send an acknowledgement reply by default.
        replyHandler(["status": "received"])
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receivedMessageSubject.send(WatchMessage.from(message))
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        receivedMessageSubject.send(.syncData(applicationContext))
    }

    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        receivedMessageSubject.send(.syncData(userInfo))
    }
}

// MARK: - Mock Implementation (for unit tests & SwiftUI previews)

#if DEBUG
final class MockWatchConnectorService: WatchConnectorServiceProtocol {

    private let watchStateSubject = CurrentValueSubject<WatchState, Never>(
        WatchState(isPaired: true, isWatchAppInstalled: true, isReachable: true,
                   isComplicationEnabled: false, activationState: .activated)
    )
    private let receivedMessageSubject = PassthroughSubject<WatchMessage, Never>()

    var watchStatePublisher: AnyPublisher<WatchState, Never> {
        watchStateSubject.eraseToAnyPublisher()
    }

    var receivedMessagePublisher: AnyPublisher<WatchMessage, Never> {
        receivedMessageSubject.eraseToAnyPublisher()
    }

    var watchState: WatchState { watchStateSubject.value }

    var activateCalled = false
    var sentMessages: [WatchMessage] = []
    var updatedContexts: [[String: Any]] = []
    var transferredUserInfos: [[String: Any]] = []
    var shouldThrowOnSend = false

    func activate() { activateCalled = true }

    func sendMessage(_ message: WatchMessage, replyHandler: (([String: Any]) -> Void)?) throws {
        if shouldThrowOnSend { throw WatchConnectorError.watchNotReachable }
        sentMessages.append(message)
        replyHandler?(["status": "mock-received"])
    }

    func updateApplicationContext(_ context: [String: Any]) throws {
        updatedContexts.append(context)
    }

    func transferUserInfo(_ userInfo: [String: Any]) {
        transferredUserInfos.append(userInfo)
    }

    /// Simulate receiving a message from the Watch.
    func simulateIncomingMessage(_ message: WatchMessage) {
        receivedMessageSubject.send(message)
    }
}
#endif
