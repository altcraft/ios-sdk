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

/// Structure for storing Alcraft configuration data.
struct Configuration {
    let url: String
    let rToken: String?
    let appInfo: AppInfo?
    let providerPriorityList: [String]?
}

/// Contains the required data for JWT request authentication.
struct JWTData {
    /// JWT token
    let jwt: String
    /// SHA-256 hash of the normalized matching claim.
    let hash: String
    /// Matching method (e.g. "push_sub").
    let matching: String
}

/// Contains the data needed to create all types of SDK requests.
///
/// - `config`: The configuration entity containing SDK settings.
/// - `currentToken`: The current device push token.
/// - `savedToken`: The previously saved push token retrieved from `UserDefaults` as the current one.
/// - `authHeader`: The authentication header required for making secure API requests.
/// - `matchingMode`: The mode used for matching authentication details.
struct CommonData {
    let config: Configuration
    let currentToken: TokenData?
    let savedToken: TokenData?
    let authHeader: String
    let matchingMode: String
}

/// Contains the data required to perform a `push/subscribe` request.
///
/// This structure is used to convert the stored `SubscribeEntity` into a usable
/// model with decoded fields, including profile data, custom fields, and categories.
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

    init(from entity: SubscribeEntity) {
        self.time = entity.time
        self.requestId = entity.uid
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

/// Represents the data required for a push notification subscription request.
struct SubscribeRequestData {
    /// The URL of the subscription API endpoint.
    let url: String

    /// The timestamp of the request in ISO format.
    let time: Int64

    /// The resource token for authentication (optional).
    let rToken: String?

    /// A unique identifier for the request.
    let requestId: String

    /// The authorization header for the request (optional).
    let authHeader: String

    /// The matching mode used for subscription identification (optional).
    let matchingMode: String

    /// The provider name (e.g., "ios-apns", "ios-firebase").
    let provider: String

    /// The device token used for push notifications.
    let deviceToken: String

    /// The subscription status.
    let status: String

    /// An optional synchronization flag.
    let sync: Int16
    
    /// A dictionary of profile  fields related to the subscription.
    let profileFields: [String: Any]?

    /// A dictionary of additional fields related to the subscription.
    let customFields: [String: Any]

    /// A dictionary of category preferences for the subscription (optional).
    let cats: [CategoryData]?

    /// A flag indicating whether to replace the existing subscription (optional).
    let replace: Bool?

    /// A flag indicating whether to skip triggers associated with the subscription (optional).
    let skipTriggers: Bool?

    /// Validates the required fields in the subscription request.
    ///
    /// - Returns: `true` if all required fields are present and valid, otherwise `false`.
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

/// Represents the data required for sending an update request.
///
/// This struct holds all the necessary parameters needed to update a token
/// or perform an authentication-related operation.
struct UpdateRequestData {
    let url: String
    let requestId: String
    let authHeader: String
    let oldToken: String?
    let newToken: String
    let oldProvider: String?
    let newProvider: String
}

/// A structure representing the necessary data for sending a push event request.
///
/// This structure encapsulates all required parameters for a push event API call,
/// ensuring that only valid data is included in the request.
struct PushEventRequestData {
    let url: String
    let time: Int64
    let type: String
    let uid: String
    let authHeader: String
    let matchingMode: String

    /// Validates the required fields in the push event request.
    ///
    /// - Returns: `true` if all required fields are present and valid, otherwise `false`.
    func isValid() -> Bool {
        let allowedTypes = [
            Constants.PushEvents.delivery, Constants.PushEvents.open
        ]
        return time > 0 &&
            !uid.isEmpty &&
            !authHeader.isEmpty &&
            !matchingMode.isEmpty &&
            allowedTypes.contains(type)
    }
}

/// Represents request data for an unSuspend reauthentication call.
struct UnSuspendRequestData {
    let url: String
    let uid: String
    let provider: String
    let token: String
    let authHeader: String
    let matchingMode: String
}

/// Represents the required data for a profile request, including the URL, headers,
/// and subscription details.
struct ProfileRequestData {
    let url: String
    let uid: String
    let authHeader: String
    let matchingMode: String
    var provider: String?
    var token: String?
}

/// Represents the necessary data for sending a mobile event request.
///
/// This struct encapsulates all required parameters for a mobile event API call,
/// ensuring that only valid data is included in the request.
///
/// - Parameters:
///   - url: The full API endpoint for the mobile event.
///   - sid: The string ID of the pixel (Altcraft client ID).
///   - name: The event name.
///   - authHeader: The authorization header (e.g. `"Bearer <token>"`).
struct MobileEventRequestData {
    let url: String
    let sid: String
    let name: String
    let authHeader: String
}

// MARK: - Public Structs

/// Stores a push token and its provider name.
///
/// Used for saving and restoring the current device token in UserDefaults.
///
/// - `provider`: Push provider ("ios-apns", "ios-firebase",  "ios-huawei").
/// - `token`: Push  token string.
public struct TokenData: Codable {
    public let provider: String
    public let token: String
}

/// Represents basic application metadata used in Firebase Analytics.
///
/// Provides identifying information about the app, its installation,
/// and version, which is attached to analytics events for tracking and reporting.
public struct AppInfo: Codable {
    
    /// The unique Firebase App identifier.
    public var appID: String
    
    /// The installation identifier (Instance ID) for this specific app installation.
    public var appIID: String
    
    /// The version string of the app.
    public var appVer: String

    /// Initializes a new `AppInfo` instance with the given app metadata.
    ///
    /// - Parameters:
    ///   - appID: The Firebase App identifier.
    ///   - appIID: The installation identifier for this app instance.
    ///   - appVer: The application version string.
    public init(
        appID: String,
        appIID: String,
        appVer: String
    ) {
        self.appID = appID
        self.appIID = appIID
        self.appVer = appVer
    }

    /// Converts `AppInfo` into a dictionary representation suitable for analytics fields.
    ///
    /// - Returns: A dictionary with keys `_app_id`, `_app_iid`, and `_app_ver`
    ///   mapped to the corresponding property values.
    func toAppFieldsMap() -> [String: String] {
        return [
            "_app_id": appID,
            "_app_iid": appIID,
            "_app_ver": appVer
        ]
    }
}

/// Wraps the API response together with the HTTP status code.
public struct ResponseWithHttp {
    public let httpCode: Int?
    public let response: Response?
}

/// Represents the response received from a synchronous subscription request.
public struct Response: Codable {
  public  let error: Int?
  public  let errorText: String?
  public  let profile: ProfileData?

    enum CodingKeys: String, CodingKey {
        case error
        case errorText = "error_text"
        case profile = "profile"
    }
}

/// Represents user profile data, including the ID, status, and subscriptions.
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

/// Represents a subscription with its ID, status, and associated categories.
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

/// Represents the details of a subscription category.
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

    // MARK: - Convenient accessors
    /// Returns the string value if case is `.string`, otherwise `nil`.
    public var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    /// Returns the numeric value if case is `.number`, otherwise `nil`.
    public var numberValue: Double? {
        if case let .number(value) = self { return value }
        return nil
    }

    /// Returns the boolean value if case is `.bool`, otherwise `nil`.
    public var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    /// Returns the object dictionary if case is `.object`, otherwise `nil`.
    public var objectValue: [String: JSONValue]? {
        if case let .object(value) = self { return value }
        return nil
    }

    /// Returns the array if case is `.array`, otherwise `nil`.
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
        case resourceId = "resource_id", email, status, priority, customFields, cats, channel
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
        case resourceId = "resource_id", phone, status, priority, customFields, cats, channel
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
    /// Unique subscription ID.
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
        case resourceId = "resource_id", provider
        case subscriptionId = "subscription_id"
        case status, priority, customFields, cats, channel
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
        case resourceId = "resource_id", channel
        case ccData = "cc_data"
        case status, priority, customFields, cats
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

/// Encoded mobile event data model used for persistence and sending.
///
/// Represents a complete mobile event including identifiers,
/// payloads, matching data, subscription info, and UTM tags.
struct MobileEventData: Codable {
    /// Altcraft client identifier.
    let altcraftClientID: String?
    /// Event name.
    let eventName: String?
    /// Matching pair encoded as JSON.
    let matching: Data?
    /// Matching type (e.g., `"email"`, `"smid"`).
    let matchingType: String?
    /// Maximum retry attempts for event delivery.
    let maxRetryCount: Int16
    /// Event payload encoded as JSON.
    let payload: Data?
    /// Profile fields encoded as JSON.
    let profileFields: Data?
    /// Current retry count.
    let retryCount: Int16
    /// Send Message ID (SMID).
    let sendMessageId: String?
    /// Pixel SID.
    let sid: String?
    /// Subscription data encoded as JSON (`Email`, `SMS`, `Push`, `CcData`).
    let subscription: Data?
    /// Event timestamp (UTC, milliseconds).
    let time: Int64
    /// Time zone offset.
    let timeZone: Int16
    /// Optional user tag associated with the event.
    let userTag: String?
    /// UTM tags encoded as JSON.
    let utmTags: Data?
    
    /// Creates a `MobileEventData` instance from a Core Data entity.
    /// - Parameter entity: The `MobileEventEntity` stored in Core Data.
    /// - Returns: A decoded `MobileEventData` ready for serialization or sending.
    static func from(entity: MobileEventEntity) -> MobileEventData {
        return MobileEventData(
            altcraftClientID: entity.altcraftClientID,
            eventName: entity.eventName,
            matching: entity.matching,
            matchingType: entity.matchingType,
            maxRetryCount: entity.maxRetryCount,
            payload: entity.payload,
            profileFields: entity.profileFields,
            retryCount: entity.retryCount,
            sendMessageId: entity.sendMessageId,
            sid: entity.sid,
            subscription: entity.subscription,
            time: entity.time,
            timeZone: entity.timeZone,
            userTag: entity.userTag,
            utmTags: entity.utmTags
        )
    }
}

/// UTM params for mobile events (all optional).
public struct UTM: Codable {
    public let campaign: String?
    public let content: String?
    public let keyword: String?
    public let medium: String?
    public let source: String?
    public let temp: String?

    /// Public initializer (all params optional).
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
