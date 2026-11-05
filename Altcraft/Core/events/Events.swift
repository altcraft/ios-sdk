//
//  Events.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// A singleton class responsible for managing event subscriptions and emissions.
///
/// `SDKEvents` allows a single subscriber to listen for events and process them.
/// The subscription can be enabled or disabled using `subscribe()` and `unsubscribe()` methods.
open class SDKEvents: NSObject, @unchecked Sendable {

    /// Shared singleton instance.
    @objc public static let shared = SDKEvents()

    /// Access to core-level SDK events.
    ///
    /// Mirrors the Android `SDKEvents.moduleEvents` object member:
    /// `AltcraftSDK.sdkEvents.moduleEvents.configSet`.
    ///
    /// The `CoreEvents` enum provides event instances as static members,
    /// so `CoreEvents` metatype access resolves cases directly
    /// (e.g. `moduleEvents.configSet`).
    @nonobjc open var moduleEvents: CoreEvents.Type { CoreEvents.self }

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
    /// Delivery is performed on the main thread: synchronously if already on
    /// main, or via the main RunLoop if on a background thread.
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

        if Thread.isMainThread {
            cb(event)
        } else {
            let box = ClosureBox {
                cb(event)
            }
            RunLoop.main.perform {
                box.invoke()
            }
        }
    }

    /// Registers an event subscriber (Objective-C entry point).
    ///
    /// - Parameter callback: Closure invoked for every emitted event.
    @available(swift, obsoleted: 1)
    @objc(subscribe:)
    public func subscribeObjC(_ callback: @escaping (Event) -> Void) {
        subscribe(callback: callback)
    }

    /// Removes the Objective-C event subscriber.
    @available(swift, obsoleted: 1)
    @objc(unsubscribe)
    public func unsubscribeObjC() {
        unsubscribe()
    }
}

/// Represents a general event with associated details.
///
/// Used for storing information about various events in the system, including errors and retryable errors.
open class Event: NSObject {
    public let id = UUID()
    public let function: String
    public let event: (any SDKEvent)?
    public let message: String?
    public let value: [String: Any]?
    public let date: Date

    /// Initializes an `Event` instance.
    ///
    /// - Parameters:
    ///   - function: Where the event occurred.
    ///   - event: SDK event type.
    ///   - message: Optional description.
    ///   - value: Optional payload dictionary.
    ///   - date: Timestamp (defaults to now).
    public init(
        function: String,
        event: (any SDKEvent)? = nil,
        message: String? = nil,
        value: [String: Any?]? = nil,
        date: Date = Date()
    ) {
        self.function = formatFunctionName(function)
        self.event = event
        self.message = message
        self.value = value?.compactMapValues { $0 }
        self.date = date
        super.init()
    }

    public var objcValue: NSDictionary? {
        value as NSDictionary?
    }

    /// Events are equal when they share the same identifier.
    ///
    /// - Parameter object: Object compared against this event.
    /// - Returns: `true` when `object` is an `Event` with the same `id`.
    public override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? Event else { return false }
        return self.id == rhs.id
    }

    public override var hash: Int {
        id.hashValue
    }
}

/// Represents an error event.
open class ErrorEvent: Event {
    public override init(
        function: String,
        event: (any SDKEvent)? = nil,
        message: String? = nil,
        value: [String: Any?]? = nil,
        date: Date = Date()
    ) {
        super.init(
            function: function,
            event: event,
            message: message,
            value: value,
            date: date
        )
    }
}

/// Represents a retryable error event.
public final class RetryEvent: ErrorEvent {
    public override init(
        function: String,
        event: (any SDKEvent)? = nil,
        message: String? = nil,
        value: [String: Any?]? = nil,
        date: Date = Date()
    ) {
        super.init(
            function: function,
            event: event,
            message: message,
            value: value,
            date: date
        )
    }
}

/// SDK error with SDKEvent and human-readable message.
public enum SDKError: Error {
    case sdk(event: any SDKEvent, message: String)

    var info: (any SDKEvent, String) {
        switch self {
        case let .sdk(event, message):
            return (event, message)
        }
    }
}

/// Creates SDKError from SDKEvent.
@_spi(_Altcraft) public enum ExceptionExtension {
    @_spi(_Altcraft) public static func exception(_ error: any SDKEvent) -> any Error {
        SDKError.sdk(event: error, message: error.message)
    }
}

/// Extracts an SDK event and message string from the provided error object.
///
/// Supports:
/// - an `SDKError`
/// - an `SDKEvent`
/// - an `NSError`
/// - an `Error`
/// - a `String`
/// - any other object via `String(describing:)`
private func extractErrorDetails(_ error: Any?) -> (event: (any SDKEvent)?, message: String) {
    if let sdk = error as? SDKError {
        let (event, message) = sdk.info
        return (event, message)
    } else if let event = error as? any SDKEvent {
        return (event, event.message)
    } else if let err = error as? NSError {
        return (nil, err.localizedDescription)
    } else if let err = error as? Error {
        return (nil, err.localizedDescription)
    } else if let str = error as? String {
        return (nil, str)
    } else if error == nil {
        return (nil, "unknown error")
    } else {
        return (nil, String(describing: error))
    }
}

/// Logs a formatted SDK message using the central logger.
/// - Parameters:
///   - function: Name of the function emitting the log.
///   - message: Text message to be logged.
private func log(function: String, message: String) {
    Logger.shared.log(
        "\(function): \(message)"
    )
}

/// Builds event log message.
/// If log payload exists, appends it to the message.
///
/// Key order in the details follows the insertion order of `logValue`
/// (preserved from `MapBuilder.createEventValue`: request fields first,
/// then response fields, then `http_code`), matching Android's log order.
private func eventLogBuilder(_ message: String?, _ logValue: ResponseModel.OrderedLogValue?) -> String {
    let base = message?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""

    let details = logValue?
        .entries
        .compactMap { entry -> String? in
            guard let value = entry.value else { return nil }
            let string = String(describing: value)
            guard !string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return "\(entry.key): \(string)"
        }
        .joined(separator: "; ") ?? ""

    return [base, details]
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

/// Emits a general event and logs it to the console.
@discardableResult
@_spi(_Altcraft) public func emitEvent(
    _ function: String,
    event: any SDKEvent,
    eventValue: [String: Any?]? = nil,
    logValue: ResponseModel.OrderedLogValue? = nil
) -> Event {
    let formattedFunc = formatFunctionName(function)
    let evMessage = eventLogBuilder(event.message, logValue)

    log(function: formattedFunc, message: evMessage)

    let ev = Event(function: formattedFunc, event: event, message: evMessage, value: eventValue)
    SDKEvents.shared.emit(event: ev)
    return ev
}

/// Emits a non-retryable error event and logs it to the console.
@discardableResult
@_spi(_Altcraft) public func errorEvent(
    _ function: String,
    error: Any?,
    eventValue: [String: Any?]? = nil,
    logValue: ResponseModel.OrderedLogValue? = nil
) -> ErrorEvent {
    let formattedFunc = formatFunctionName(function)
    let (event, message) = extractErrorDetails(error)
    let evMessage = eventLogBuilder(message, logValue)

    log(function: formattedFunc, message: evMessage)

    let err = ErrorEvent(function: formattedFunc, event: event, message: evMessage, value: eventValue)
    SDKEvents.shared.emit(event: err)
    return err
}

/// Emits a retryable error event and logs it to the console.
@discardableResult
@_spi(_Altcraft) public func retryEvent(
    _ function: String,
    error: Any?,
    eventValue: [String: Any?]? = nil,
    logValue: ResponseModel.OrderedLogValue? = nil
) -> RetryEvent {
    let formattedFunc = formatFunctionName(function)
    let (event, message) = extractErrorDetails(error)
    let evMessage = eventLogBuilder(message, logValue)

    log(function: formattedFunc, message: evMessage)

    let retry = RetryEvent(function: formattedFunc, event: event, message: evMessage,value: eventValue)
    SDKEvents.shared.emit(event: retry)
    return retry
}
