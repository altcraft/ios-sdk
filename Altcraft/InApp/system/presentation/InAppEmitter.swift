//
//  InAppEmitter.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Emits in-app campaigns with content type `json` to a single external subscriber.
///
/// Thread-safe: subscription state is protected by a dedicated serial queue.
/// The `emit` method dispatches callbacks to the main thread when called from
/// a background thread.
@objcMembers
@available(iOSApplicationExtension, unavailable)
final class InAppEmitter: NSObject, @unchecked Sendable {

    static let shared = InAppEmitter()

    private let stateQueue = DispatchQueue(
        label: InAppConstants.Queues.inAppEmitterState
    )

    private var subscriber: ((String) -> Void)?
    private var isSubscribed = false

    private override init() {
        super.init()
    }

    /// Registers a subscriber that will receive emitted JSON in-app campaigns.
    func subscribe(
        callback: @escaping (String) -> Void
    ) {
        stateQueue.sync {
            subscriber = callback
            isSubscribed = true
        }
    }

    /// Removes the current subscriber.
    func unsubscribe() {
        stateQueue.sync {
            subscriber = nil
            isSubscribed = false
        }
    }

    /// Emits a JSON in-app campaign to the current subscriber.
    ///
    /// If called from a background thread, the callback is dispatched to the main
    /// run loop. Safe to call from any thread.
    ///
    /// - Parameter json: Raw JSON string of the in-app campaign.
    internal func emit(json: String) {
        let cb: ((String) -> Void)? = stateQueue.sync {
            guard isSubscribed, let subscriber else {
                return nil
            }

            return subscriber
        }

        guard let cb else {
            return
        }

        if Thread.isMainThread {
            cb(json)
        } else {
            let box = ClosureBox {
                cb(json)
            }

            RunLoop.main.perform {
                box.invoke()
            }
        }
    }
}

/// Provides subscription to in-app placements with JSON content.
///
/// Mirrors the Android `JsonContentAPI` object: the host application
/// registers a subscriber that receives the raw JSON of JSON-content
/// campaigns handled by the SDK.
@available(iOSApplicationExtension, unavailable)
public final class JsonContentAPI: @unchecked Sendable {

    /// Shared API instance.
    public static let shared = JsonContentAPI()

    private init() {}

    /// Registers a subscriber that will receive JSON content
    /// from in-app placements.
    ///
    /// A new subscriber replaces the previous one.
    ///
    /// - Parameter newSubscriber: Callback invoked when JSON content is received.
    public func subscribe(_ newSubscriber: @escaping (String) -> Void) {
        InAppEmitter.shared.subscribe(callback: newSubscriber)
    }

    /// Removes the current subscriber.
    public func unsubscribe() {
        InAppEmitter.shared.unsubscribe()
    }
}
