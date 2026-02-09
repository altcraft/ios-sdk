//
//  Structures.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

// MARK: - Internal Structs

/// Altcraft SDK configuration.
///
/// Holds base parameters required to build requests and drive SDK behavior.
struct Configuration {
    /// Base API URL.
    let url: String
    /// Resource token (optional).
    let rToken: String?
    /// Application metadata (optional).
    let appInfo: AppInfo?
    /// Push provider priority list (optional).
    let providerPriorityList: [String]?
}

/// JWT authentication payload.
///
/// Used when requests require JWT + a SHA-256 hash of a normalized matching claim.
struct JWTData {
    /// JWT token.
    let jwt: String
    /// SHA-256 hash of the normalized matching claim.
    let hash: String
    /// Matching method (e.g., `"push_sub"`).
    let matching: String
}

/// Common data required to construct SDK network requests.
struct RequestData {
    /// SDK configuration (optional).
    let config: Configuration?
    /// Authorization tuple (key, value) (optional).
    let auth: (String, String)?
}

/// Subscription model restored from Core Data.
///
/// Converts a stored `SubscribeEntity` into a usable model with decoded fields,
/// including profile data, custom fields, and categories.
struct Subscribe {
    let time: Int64?
    let requestId: String?
    let userTag: String?
    let status: String?
    let sync: Int16?
    let replace: Bool?
    let skipTriggers: Bool?
    let retryCount: Int16
    let maxRetryCount: Int16
    let profileFields: [String: Any]?
    let customFields: [String: Any]?
    let cats: [CategoryData]?

    /// Creates a `Subscribe` model from `SubscribeEntity`.
    ///
    /// - Note: `profileFields` and `customFields` are expected to be stored as encoded
    ///         dictionaries; decoding is performed via `decodeAnyMap`.
    init(from entity: SubscribeEntity) {
        self.time = entity.time
        self.requestId = entity.requestId
        self.userTag = entity.userTag
        self.status = entity.status
        self.sync = entity.sync
        self.replace = entity.replace
        self.skipTriggers = entity.skipTriggers
        self.retryCount = entity.retryCount
        self.maxRetryCount = entity.maxRetryCount

        self.profileFields = entity.profileFields.flatMap(decodeAnyMap)
        self.customFields = entity.customFields.flatMap(decodeAnyMap)
        self.cats = entity.cats.flatMap {
            try? JSONDecoder().decode([CategoryData].self, from: $0)
        }
    }
}

/// Data required to perform a `push/subscribe` request.
struct SubscribeRequestData {
    /// Subscription API endpoint URL.
    let url: String

    /// Unique request identifier.
    let requestId: String

    /// Timestamp in epoch milliseconds.
    let time: Int64

    /// Resource token (optional).
    let rToken: String?

    /// Authorization header value.
    let authHeader: String

    /// Matching mode used for subscription identification.
    let matchingMode: String

    /// Provider name (e.g., `"ios-apns"`, `"ios-firebase"`).
    let provider: String

    /// Device token used for push notifications.
    let deviceToken: String

    /// Subscription status.
    let status: String

    /// Synchronization flag.
    let sync: Bool

    /// Profile fields associated with the subscription (optional).
    let profileFields: [String: Any]?

    /// Additional custom fields (may be empty, but not nil).
    let customFields: [String: Any]

    /// Category preferences (optional).
    let cats: [CategoryData]?

    /// Whether to replace an existing subscription (optional).
    let replace: Bool?

    /// Whether to skip triggers associated with the subscription (optional).
    let skipTriggers: Bool?

    /// Validates required fields.
    ///
    /// - Returns: `true` if required fields are present and valid; otherwise `false`.
    func isValid() -> Bool {
        return time != 0 &&
        !requestId.isEmpty &&
        !authHeader.isEmpty &&
        !matchingMode.isEmpty &&
        !provider.isEmpty &&
        !deviceToken.isEmpty &&
        !status.isEmpty
    }
}

/// Data required to perform a token update request.
struct UpdateRequestData {
    let url: String
    let requestId: String
    let authHeader: String
    let oldToken: String?
    let newToken: String
    let oldProvider: String?
    let newProvider: String
    let sync: Bool
}

/// Data required to perform a push event request.
///
/// Encapsulates required parameters for a push event API call and provides validation.
struct PushEventRequestData {
    let url: String
    let requestId: String
    let time: Int64
    let type: String
    let uid: String
    let authHeader: String
    let matchingMode: String

    /// Validates required fields and event type.
    ///
    /// - Returns: `true` if required fields are present and valid; otherwise `false`.
    func isValid() -> Bool {
        let allowedTypes = [
            Constants.PushEvents.delivery,
            Constants.PushEvents.open
        ]
        return time > 0 &&
            !uid.isEmpty &&
            !authHeader.isEmpty &&
            !matchingMode.isEmpty &&
            allowedTypes.contains(type)
    }
}

/// Data required to perform an `unSuspend` re-authentication request.
struct UnSuspendRequestData {
    let url: String
    let requestId: String
    let provider: String
    let token: String
    let authHeader: String
    let matchingMode: String
}

/// Data required to perform a profile request.
///
/// Includes endpoint URL, headers, matching mode, and optional subscription details.
struct ProfileRequestData {
    let url: String
    let requestId: String
    let authHeader: String
    let matchingMode: String
    var provider: String?
    var token: String?
}

/// Data required to perform a mobile event request.
///
/// Encapsulates parameters for a mobile event API call.
/// - Parameters:
///   - url: Full API endpoint URL.
///   - sid: Pixel identifier (Altcraft client ID).
///   - eventName: Event name.
///   - parts: Event parts.
///   - authHeader: Authorization header value (e.g., `"Bearer <token>"`).
struct MobileEventRequestData {
    let url: String
    let requestId: String
    let sid: String
    let eventName: String
    let parts: [Part]
    let authHeader: String
}

// MARK: - Public Structs

/// Push token and provider.
///
/// Used to persist and restore the current device token in `UserDefaults`.
/// - `provider`: Push provider (e.g., `"ios-apns"`, `"ios-firebase"`, `"ios-huawei"`).
/// - `token`: Push token string.
public struct TokenData: Codable {
    public let provider: String
    public let token: String
}

/// Application metadata used for analytics.
///
/// Provides basic app identifiers attached to events for tracking and reporting.
public struct AppInfo: Codable {

    /// Unique application identifier.
    public var appID: String

    /// Installation identifier for this specific app instance.
    public var appIID: String

    /// Application version string.
    public var appVer: String

    /// Creates a new `AppInfo`.
    ///
    /// - Parameters:
    ///   - appID: Application identifier.
    ///   - appIID: Installation identifier.
    ///   - appVer: Application version.
    public init(
        appID: String,
        appIID: String,
        appVer: String
    ) {
        self.appID = appID
        self.appIID = appIID
        self.appVer = appVer
    }

    /// Converts `AppInfo` into a string map suitable for analytics fields.
    ///
    /// - Returns: A dictionary with `_app_id`, `_app_iid`, and `_app_ver`.
    func toAppFieldsMap() -> [String: String] {
        return [
            "_app_id": appID,
            "_app_iid": appIID,
            "_app_ver": appVer
        ]
    }
}

/// Wraps an API response together with an HTTP status code.
public struct ResponseWithHttp {
    public let httpCode: Int?
    public let response: Response?
}

/// Synchronous subscribe response payload.
public struct Response: Codable {
    public let error: Int?
    public let errorText: String?
    public let profile: ProfileData?

    enum CodingKeys: String, CodingKey {
        case error
        case errorText = "error_text"
        case profile = "profile"
    }
}

/// User profile payload, including status and subscription details.
public struct ProfileData: Codable {
    public let id: String?
    public let status: String?
    public let isTest: Bool?
    public let subscription: SubscriptionData?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case isTest = "is_test"
        case subscription
    }
}

/// Subscription payload including provider, fields, and categories.
public struct SubscriptionData: Codable {
    public let subscriptionId: String?
    public let hashId: String?
    public let provider: String?
    public let status: String?
    public let fields: [String: JSONValue]?
    public let cats: [CategoryData]?

    enum CodingKeys: String, CodingKey {
        case subscriptionId = "subscription_id"
        case hashId = "hash_id"
        case provider
        case status
        case fields
        case cats
    }
}

/// Subscription category details.
public struct CategoryData: Codable {
    public var name: String?
    public var title: String? = nil
    public var steady: Bool? = nil
    public var active: Bool?

    public init(
        name: String?,
        title: String? = nil,
        steady: Bool? = nil,
        active: Bool?
    ) {
        self.name = name
        self.title = title
        self.steady = steady
        self.active = active
    }
}

/// A type-safe representation of any JSON value.
///
/// Supports strings, numbers, booleans, objects, arrays, and null.
public enum JSONValue: Codable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let num = try? container.decode(Double.self) {
            self = .number(num)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let obj = try? container.decode([String: JSONValue].self) {
            self = .object(obj)
        } else if let arr = try? container.decode([JSONValue].self) {
            self = .array(arr)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value):   try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value):  try container.encode(value)
        case .null:              try container.encodeNil()
        }
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .string(let value): return value
        case .number(let value): return String(value)
        case .bool(let value):   return String(value)
        case .object(let value): return value.mapValues { $0.description }.description
        case .array(let value):  return value.map { $0.description }.description
        case .null:              return "null"
        }
    }

    // MARK: - Convenience accessors

    /// Returns the underlying string when the value is `.string`.
    public var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    /// Returns the underlying number when the value is `.number`.
    public var numberValue: Double? {
        if case let .number(value) = self { return value }
        return nil
    }

    /// Returns the underlying boolean when the value is `.bool`.
    public var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    /// Returns the underlying object when the value is `.object`.
    public var objectValue: [String: JSONValue]? {
        if case let .object(value) = self { return value }
        return nil
    }

    /// Returns the underlying array when the value is `.array`.
    public var arrayValue: [JSONValue]? {
        if case let .array(value) = self { return value }
        return nil
    }
}

/// Email channel subscription.
public struct EmailSubscription: Subscription, Codable {
    /// Resource identifier.
    public let resourceId: Int
    /// Email address.
    public let email: String
    /// Subscription status (optional).
    public let status: String?
    /// Subscription priority (optional).
    public let priority: Int?
    /// Custom subscription fields (optional).
    public let customFields: [String: JSONValue]?
    /// Subscription categories (optional).
    public let cats: [String]?
    /// Channel type, always `"email"`.
    public let channel: String = "email"

    enum CodingKeys: String, CodingKey {
        case resourceId = "resource_id"
        case email
        case status
        case priority
        case customFields = "custom_fields"
        case cats
        case channel
    }

    public init(
        resourceId: Int,
        email: String,
        status: String? = nil,
        priority: Int? = nil,
        customFields: [String: JSONValue]? = nil,
        cats: [String]? = nil
    ) {
        self.resourceId = resourceId
        self.email = email
        self.status = status
        self.priority = priority
        self.customFields = customFields
        self.cats = cats
    }
}

/// SMS channel subscription.
public struct SmsSubscription: Subscription, Codable {
    /// Resource identifier.
    public let resourceId: Int
    /// Phone number.
    public let phone: String
    /// Subscription status (optional).
    public let status: String?
    /// Subscription priority (optional).
    public let priority: Int?
    /// Custom subscription fields (optional).
    public let customFields: [String: JSONValue]?
    /// Subscription categories (optional).
    public let cats: [String]?
    /// Channel type, always `"sms"`.
    public let channel: String = "sms"

    enum CodingKeys: String, CodingKey {
        case resourceId = "resource_id"
        case phone
        case status
        case priority
        case customFields = "custom_fields"
        case cats
        case channel
    }

    public init(
        resourceId: Int,
        phone: String,
        status: String? = nil,
        priority: Int? = nil,
        customFields: [String: JSONValue]? = nil,
        cats: [String]? = nil
    ) {
        self.resourceId = resourceId
        self.phone = phone
        self.status = status
        self.priority = priority
        self.customFields = customFields
        self.cats = cats
    }
}

/// Push channel subscription.
public struct PushSubscription: Subscription, Codable {
    /// Resource identifier.
    public let resourceId: Int
    /// Provider name (e.g., `"ios-apns"`).
    public let provider: String
    /// Unique subscription identifier.
    public let subscriptionId: String
    /// Subscription status (optional).
    public let status: String?
    /// Subscription priority (optional).
    public let priority: Int?
    /// Custom subscription fields (optional).
    public let customFields: [String: JSONValue]?
    /// Subscription categories (optional).
    public let cats: [String]?
    /// Channel type, always `"push"`.
    public let channel: String = "push"

    enum CodingKeys: String, CodingKey {
        case resourceId = "resource_id"
        case provider
        case subscriptionId = "subscription_id"
        case status
        case priority
        case customFields = "custom_fields"
        case cats
        case channel
    }

    public init(
        resourceId: Int,
        provider: String,
        subscriptionId: String,
        status: String? = nil,
        priority: Int? = nil,
        customFields: [String: JSONValue]? = nil,
        cats: [String]? = nil
    ) {
        self.resourceId = resourceId
        self.provider = provider
        self.subscriptionId = subscriptionId
        self.status = status
        self.priority = priority
        self.customFields = customFields
        self.cats = cats
    }
}

/// Subscription with `cc_data`, used for Telegram, WhatsApp, Viber, and Notify.
public struct CcDataSubscription: Subscription, Codable {
    /// Resource identifier.
    public let resourceId: Int
    /// Channel type (e.g., `"telegram_bot"`, `"whatsapp"`).
    public let channel: String
    /// Channel-specific data (e.g., chat ID).
    public let ccData: [String: JSONValue]
    /// Subscription status (optional).
    public let status: String?
    /// Subscription priority (optional).
    public let priority: Int?
    /// Custom subscription fields (optional).
    public let customFields: [String: JSONValue]?
    /// Subscription categories (optional).
    public let cats: [String]?

    enum CodingKeys: String, CodingKey {
        case resourceId = "resource_id"
        case channel
        case ccData = "cc_data"
        case status
        case priority
        case customFields = "custom_fields"
        case cats
    }

    public init(
        resourceId: Int,
        channel: String,
        ccData: [String: JSONValue],
        status: String? = nil,
        priority: Int? = nil,
        customFields: [String: JSONValue]? = nil,
        cats: [String]? = nil
    ) {
        self.resourceId = resourceId
        self.channel = channel
        self.ccData = ccData
        self.status = status
        self.priority = priority
        self.customFields = customFields
        self.cats = cats
    }
}

/// UTM parameters for mobile events (all optional).
public struct UTM: Codable {
    public let campaign: String?
    public let content: String?
    public let keyword: String?
    public let medium: String?
    public let source: String?
    public let temp: String?

    /// Creates a new `UTM` instance (all parameters are optional).
    public init(
        campaign: String? = nil,
        content: String? = nil,
        keyword: String? = nil,
        medium: String? = nil,
        source: String? = nil,
        temp: String? = nil
    ) {
        self.campaign = campaign
        self.content = content
        self.keyword = keyword
        self.medium = medium
        self.source = source
        self.temp = temp
    }
}
