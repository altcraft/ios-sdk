//
//  Events.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

import Foundation

/// A singleton class responsible for managing event subscriptions and emissions.
///
/// `SDKEvents` allows a single subscriber to listen for events and process them.
/// The subscription can be enabled or disabled using `subscribe()` and `unsubscribe()` methods.
open class SDKEvents: NSObject, @unchecked Sendable {
    
    /// Shared singleton instance.
    @objc public static let shared = SDKEvents()

    private let stateQueue = DispatchQueue(
        label: "com.altcraft.sdkevents.state"
    )
    private var subscriber: ((Event) -> Void)?
    private var isSubscribed: Bool = true

    public override init() {
        super.init()
    }
    
    /// Subscribes to SDK events.
    /// Callback is always delivered on the main thread.
    open func subscribe(
        callback: @escaping (Event) -> Void
    ) {
        stateQueue.sync {
            subscriber = callback
            isSubscribed = true
        }
    }

    /// Backward-compatible overload.
    /// `queue` is ignored intentionally because events are always delivered on main.
    open func subscribe(
        on queue: DispatchQueue = .main,
        callback: @escaping (Event) -> Void
    ) {
        stateQueue.sync {
            subscriber = callback
            isSubscribed = true
        }
    }

    /// Disables event delivery to the current subscriber.
    open func unsubscribe() {
        stateQueue.sync {
            isSubscribed = false
        }
    }

    /// Emits an event to the current subscriber if subscribed.
    /// Delivery is always performed on the main thread.
    @nonobjc
    open func emit(event: Event) {
        let cb: ((Event) -> Void)? = stateQueue.sync {
            guard isSubscribed, let cb = subscriber else {
                return nil
            }
            return cb
        }

        guard let cb else {
            return
        }

        completeOnMain {
            cb(event)
        }
    }

    @available(swift, obsoleted: 1)
    @objc(subscribe:)
    public func subscribeObjC(_ callback: @escaping (Event) -> Void) {
        subscribe(callback: callback)
    }

    @available(swift, obsoleted: 1)
    @objc(unsubscribe)
    public func unsubscribeObjC() {
        unsubscribe()
    }
}

/// Represents a general event with associated details.
///
/// Used for storing information about various events in the system, including errors and retryable errors.
@objcMembers
open class Event: NSObject{
    public let id = UUID()
    public let function: String
    public let message: String?
    public let eventCode: Int?
    public let value: [String: Any]?
    public let date: Date

    /// Initializes an `Event` instance.
    ///
    /// - Parameters:
    ///   - function: Where the event occurred.
    ///   - message: Optional description.
    ///   - eventCode: Optional numeric code.
    ///   - value: Optional payload dictionary.
    ///   - date: Timestamp (defaults to now).
    public init(
        function: String,
        message: String? = nil,
        eventCode: Int? = nil,
        value: [String: Any?]? = nil,
        date: Date = Date()
    ) {
        self.function = formatFunctionName(function)
        self.message = message
        self.eventCode = eventCode
        self.value = value?.compactMapValues { $0 }
        self.date = date
        super.init()
    }

    public var objcEventCode: NSNumber? {
        eventCode.map(NSNumber.init(value:))
    }
    public var objcValue: NSDictionary? {
        value as NSDictionary?
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? Event else { return false }
        return self.id == rhs.id
    }

    public override var hash: Int {
        id.hashValue
    }
}

/// Represents an error event.
@objcMembers
open class ErrorEvent: Event{
    public override init(
        function: String,
        message: String? = nil,
        eventCode: Int? = nil,
        value: [String: Any?]? = nil,
        date: Date = Date()
    ) {
        super.init(
            function: function,
            message: message,
            eventCode: eventCode,
            value: value,
            date: date
        )
    }
}

/// Represents a retryable error event.
@objcMembers
public class RetryEvent: ErrorEvent {
    public override init(
        function: String,
        message: String? = nil,
        eventCode: Int? = 0,
        value: [String: Any?]? = nil,
        date: Date = Date()
    ) {
        super.init(
            function: function,
            message: message,
            eventCode: eventCode,
            value: value,
            date: date
        )
    }
}

/// SDK error with numeric code and human-readable message.
internal enum SDKError: Error {
    case sdk(code: Int, message: String)

    var info: (Int, String) {
        switch self {
        case let .sdk(code, message): return (code, message)
        }
    }
}

/// Creates SDKError from EventList pair.
internal enum ExceptionExtension {
    static func exception(_ error: (Int, String)) -> SDKError {
        .sdk(code: error.0, message: error.1)
    }
}

/// Extracts an integer error code and message string from the provided error object.
///
/// Supports:
/// - a tuple `(Int, String)`
/// - an `NSError` (code depends on `retry`)
/// - a `String`
/// - any other object via `String(describing:)`
/// Extracts an integer error code and message string from the provided error object.
private func extractErrorDetails(_ error: Any?, retry: Bool) -> (code: Int, message: String) {
    if let sdk = error as? SDKError {
        let (code, message) = sdk.info
        return (code, message)
    } else if let pair = error as? (Int, String) {
        return (pair.0, pair.1)
    } else if let err = error as? NSError {
        return (retry ? 500 : 400, err.localizedDescription)
    } else if let err = error as? Error {
        return (retry ? 500 : 400, err.localizedDescription)
    } else if let str = error as? String {
        return (0, str)
    } else {
        return (0, String(describing: error))
    }
}

/// Logs a formatted SDK message using the central logger.
/// - Parameters:
///   - function: Name of the function emitting the log.
///   - message: Text message to be logged.
private func log(function: String, message: String) {
    Logger.shared.log(
        "\(Constants.Log.logPrefix): \(function): \(message)"
    )
}

/// Emits a general event and logs it to the console.
@discardableResult
func event(_ function: String, event: (Int, String), value: [String: Any?]? = nil) -> Event {
    let formattedFunc = formatFunctionName(function)
    let (code, message) = event

    log(function: formattedFunc, message: message)

    let ev = Event(function: formattedFunc, message: message, eventCode: code, value: value)
    SDKEvents.shared.emit(event: ev)
    return ev
}

/// Emits a non-retryable error event and logs it to the console.
@discardableResult
func errorEvent(_ function: String, error: Any?, value: [String: Any?]? = nil) -> ErrorEvent {
    let formattedFunc = formatFunctionName(function)
    let (code, message) = extractErrorDetails(error, retry: false)

    log(function: formattedFunc, message: message)

    let err = ErrorEvent(function: formattedFunc, message: message, eventCode: code, value: value)
    SDKEvents.shared.emit(event: err)
    return err
}

/// Emits a retryable error event and logs it to the console.
@discardableResult
func retryEvent(_ function: String, error: Any?, value: [String: Any?]? = nil) -> RetryEvent {
    let formattedFunc = formatFunctionName(function)
    let (code, message) = extractErrorDetails(error, retry: true)

    log(function: formattedFunc, message: message)

    let retry = RetryEvent(function: formattedFunc, message: message, eventCode: code, value: value)
    SDKEvents.shared.emit(event: retry)
    return retry
}
