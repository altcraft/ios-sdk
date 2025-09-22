//
//  Events.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

/// A singleton class responsible for managing event subscriptions and emissions.
///
/// `SDKEvents` allows a single subscriber to listen for events and process them.
/// The subscription can be enabled or disabled using `subscribe()` and `unsubscribe()` methods.
open class SDKEvents: NSObject {
    
    /// The shared singleton instance of `SDKEvents`.
    public static let shared = SDKEvents()

    /// The single subscriber callback function that processes emitted events.
    private var subscriber: ((Event) -> Void)?
    
    /// A flag indicating whether events should be emitted to the subscriber.
    private var isSubscribed: Bool = true

    /// Initializes the `SDKEvents` instance.
    override init() {
        super.init()
    }

    /// Subscribes a callback function to receive events.
    ///
    /// - Parameter callback: A closure that takes an `Event` object as a parameter.
    ///   This closure will be called whenever an event is emitted.
    ///
    /// - Note: Calling this method replaces any existing subscriber.
    open func subscribe(callback: @escaping (Event) -> Void) {
        self.subscriber = callback
        self.isSubscribed = true
    }

    /// Unsubscribes the current subscriber, preventing further event emissions.
    ///
    /// - Note: The subscriber callback remains assigned but will no longer receive events.
    open func unsubscribe() {
        self.isSubscribed = false
    }

    /// Emits an event to the current subscriber if the subscription is active.
    ///
    /// - Parameter event: The `Event` object containing event details.
    ///
    /// - Note: If no subscriber is set or `isSubscribed` is `false`, the event will not be emitted.
    open func emit(event: Event) {
        if isSubscribed {
            subscriber?(event)
        }
    }
}

/// Represents a general event with associated details.
///
/// Used for storing information about various events in the system, including errors and retryable errors.
open class Event: Hashable {
    public let id = UUID()
    public let function: String
    public let message: String?
    public let eventCode: Int?
    public let value: [String: Any?]?
    public let date: Date

    /// Initializes an `Event` instance.
    ///
    /// - Parameters:
    ///   - function: The name or identifier of the function where the event occurred.
    ///   - message: An optional message providing additional details about the event.
    ///   - eventCode: An optional code identifying the event type.
    ///   - value: An optional value associated with the event.
    ///   - date: The date and time when the event occurred (default is the current date and time).
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
    }

    /// Equatable conformance: Compares events based on their unique `id`.
    public static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.id == rhs.id
    }

    /// Hashable conformance: Uses the `id` for generating a hash value.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Represents an error event, extending the general event class.
///
/// Used for storing information about errors that occur in the system.
open class ErrorEvent: Event {
    
    /// Initializes an `ErrorEvent` instance.
    ///
    /// - Parameters:
    ///   - function: The name or identifier of the function where the error occurred.
    ///   - message: An optional message providing details about the error.
    ///   - eventCode: An optional code identifying the error type.
    ///   - value: An optional value associated with the error.
    ///   - date: The date and time when the error occurred (default is the current date and time).
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
///
/// This class extends `ErrorEvent` and is used for errors that support retry mechanisms.
public class RetryEvent: ErrorEvent {
    
    /// Initializes a `RetryError` instance.
    ///
    /// - Parameters:
    ///   - function: The name or identifier of the function where the retryable error occurred.
    ///   - message: An optional message providing details about the retryable error.
    ///   - eventCode: An optional code identifying the retryable error type (default is `"ER"`).
    ///   - value: An optional value associated with the retryable error.
    ///   - date: The date and time when the retryable error occurred (default is the current date and time).
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

/// Extracts an integer error code and message string from the provided error object.
///
/// The method supports:
/// - a tuple `(Int, String)`
/// - an `NSError` object (returns localized description and code based on `retry`)
/// - a `String` (returns it as message with code `0`)
/// - any other object (calls `String(describing:)`)
///
/// - Parameters:
///   - error: The error object to extract details from.
///   - retry: Flag indicating if the error is retryable (affects fallback error code).
/// - Returns: A tuple with an integer error code and message string.
private func extractErrorDetails(_ error: Any?, retry: Bool) -> (code: Int, message: String) {
    if let pair = error as? (Int, String) {
        return (pair.0, pair.1)
    } else if let err = error as? NSError {
        return (retry ? 500 : 400, err.localizedDescription)
    } else if let str = error as? String {
        return (0, str)
    } else {
        return (0, String(describing: error))
    }
}

/// Emits a general event and logs it to the console.
///
/// This is a lightweight event that carries a numeric code and a descriptive message,
/// along with optional payload data.
///
/// - Parameters:
///   - function: The name of the function or context where the event originated.
///   - event: A tuple containing an event code (`Int`) and message (`String`).
///   - value: Optional dictionary with additional payload data.
/// - Returns: The emitted `Event` object.
@discardableResult
func event(_ function: String, event: (Int, String), value: [String: Any?]? = nil) -> Event {
    let formattedFunc = formatFunctionName(function)
    let (code, message) = event

    print("\(formattedFunc): \(message)")

    let ev = Event(function: formattedFunc, message: message, eventCode: code, value: value)
    SDKEvents.shared.emit(event: ev)
    return ev
}

/// Emits a non-retryable error event and logs it to the console.
///
/// Automatically extracts a numeric error code and message string from the provided error,
/// which may be a tuple, string, exception, or other object.
///
/// - Parameters:
///   - function: The name of the function or context where the error occurred.
///   - error: The error object or description; accepted types include `String`, `(Int, String)`, or `NSError`.
///   - value: Optional dictionary with additional error details.
/// - Returns: The emitted `ErrorEvent` object.
@discardableResult
func errorEvent(_ function: String, error: Any?, value: [String: Any?]? = nil) -> ErrorEvent {
    let formattedFunc = formatFunctionName(function)
    let (code, message) = extractErrorDetails(error, retry: false)

    print("\(formattedFunc): \(message)")

    let err = ErrorEvent(function: formattedFunc, message: message, eventCode: code, value: value)
    SDKEvents.shared.emit(event: err)
    return err
}

/// Emits a retryable error event and logs it to the console.
///
/// The emitted event indicates a recoverable failure. The error code is set to `500` by default
/// for unknown retryable errors, or extracted from the provided object if possible.
///
/// - Parameters:
///   - function: The name of the function or context where the retryable error occurred.
///   - error: The error object or description; accepted types include `String`, `(Int, String)`, or `NSError`.
///   - value: Optional dictionary with additional retry-related data.
/// - Returns: The emitted `RetryEvent` object.
@discardableResult
func retryEvent(_ function: String, error: Any?, value: [String: Any?]? = nil) -> RetryEvent {
    let formattedFunc = formatFunctionName(function)
    let (code, message) = extractErrorDetails(error, retry: true)

    print("\(formattedFunc): \(message)")

    let retry = RetryEvent(function: formattedFunc, message: message, eventCode: code, value: value)
    SDKEvents.shared.emit(event: retry)
    return retry
}


