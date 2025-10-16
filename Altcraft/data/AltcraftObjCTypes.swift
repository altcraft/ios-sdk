//
//  AltcraftObjCTypes.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import Foundation

// MARK: - Configuration

/// Objective-C compatible DTO used to pass  Firebase analytics app metadata (app ID, install ID, version)
/// from Objective-C environments into the Swift SDK.
/// This class acts as a lightweight bridge between Objective-C and Swift models.
@objcMembers
public final class AppInfoObjC: NSObject {
    public let appID: String
    public let appIID: String
    public let appVer: String

    public init(appID: String, appIID: String, appVer: String) {
        self.appID = appID
        self.appIID = appIID
        self.appVer = appVer
        super.init()
    }
}

// MARK: - PublicPushSubscriptionFunctions

/// Objective-C–friendly representation of a subscription category.
///
/// Mirrors the Swift `CategoryData` type, but uses an `NSObject` subclass so
/// it can be consumed directly from Objective-C code.
///
/// ```objc
/// ACTCategoryData *news = [[ACTCategoryData alloc] initWithName:@"news"
///                                                         title:@"News"
///                                                        steady:YES
///                                                        active:YES];
/// ```
@objcMembers
public final class CategoryDataObjC: NSObject {
    public let name: String
    public let title: String
    public let steady: Bool
    public let active: Bool

    public init(name: String, title: String, steady: Bool, active: Bool) {
        self.name = name
        self.title = title
        self.steady = steady
        self.active = active
        super.init()
    }

    /// Swift -> ObjC factory. Returns `nil` if required fields are missing.
    /// Notes about defaults on Swift optional fields:
    /// - `name`: required (otherwise returns `nil`)
    /// - `title`: defaults to `""`
    /// - `steady`: defaults to `false`
    /// - `active`: defaults to `false`
    internal static func fromSwift(_ c: CategoryData) -> CategoryDataObjC? {
        guard let name = c.name else { return nil }
        let title = c.title ?? ""
        let steady = c.steady ?? false
        let active = c.active ?? false
        return CategoryDataObjC(name: name, title: title, steady: steady, active: active)
    }

    /// ObjC -> Swift converter for arrays of categories.
    /// Converts `[ACTCategoryData]` into `[CategoryData]`.
    internal static func toSwiftArray(_ arr: [CategoryDataObjC]?) -> [CategoryData]? {
        guard let arr, !arr.isEmpty else { return [] }
        return arr.map {
            CategoryData(
                name: $0.name,
                title: $0.title,
                steady: $0.steady,
                active: $0.active
            )
        }
    }
}

/// Objective-C–friendly wrapper for the Swift `ResponseWithHttp` struct.
/// Carries the HTTP code and a raw NSDictionary representation of `Response`
/// (if encoding is possible).
@objcMembers
public final class ResponseWithHttpObjC: NSObject {
    public let httpCode: NSNumber?
    public let responseJSON: NSDictionary?

    public init(httpCode: NSNumber?, responseJSON: NSDictionary?) {
        self.httpCode = httpCode
        self.responseJSON = responseJSON
        super.init()
    }

    /// Factory from Swift `ResponseWithHttp`.
    internal static func from(_ s: ResponseWithHttp?) -> ResponseWithHttpObjC? {
        guard let s else { return nil }
        let codeNum = s.httpCode.map { NSNumber(value: $0) }
        let json: NSDictionary?
        if let resp = s.response {
            json = (try? encodeResponseToNSDictionary(resp)) ?? nil
        } else {
            json = nil
        }
        return ResponseWithHttpObjC(httpCode: codeNum, responseJSON: json)
    }
}

/// Helper: encode Swift `Response` (assumed `Codable`) to NSDictionary for Objective-C callers.
/// If `Response` is not `Codable`, replace this encoder with a custom mapper.
private func encodeResponseToNSDictionary(_ response: Response) throws -> NSDictionary {
    let data = try JSONEncoder().encode(response)
    let obj = try JSONSerialization.jsonObject(with: data, options: [])
    return obj as? NSDictionary ?? [:]
}


// MARK: - PublicPushTokenFunctions

/// Objective-C wrapper for a push token + provider pair.
@objcMembers
public final class TokenDataObjC: NSObject {
    public let provider: String
    public let token: String

    public init(provider: String, token: String) {
        self.provider = provider
        self.token = token
        super.init()
    }

    /// Convenience factory from Swift TokenData.
    internal static func from(_ td: TokenData?) -> TokenDataObjC? {
        guard let td, !td.provider.isEmpty, !td.token.isEmpty else { return nil }
        return TokenDataObjC(provider: td.provider, token: td.token)
    }
}

// MARK: - MobileEvent

/// Base ObjC-visible subscription type.
/// Subclasses must convert themselves to a concrete Swift `Subscription` via `toSwift()`.
@objcMembers
public class SubscriptionObjC: NSObject {
    /// SDK bridge (not exposed to ObjC callers).
    internal func toSwift() -> (any Subscription)? { nil }
}

/// Email channel subscription (ObjC bridge).
/// Mirrors Swift `EmailSubscription`: email address + optional status/priority/custom fields/categories.
@objcMembers
public final class EmailSubscriptionObjC: SubscriptionObjC {
    /// Resource identifier.
    public let resourceId: NSNumber
    /// Email address.
    public let email: String
    /// Subscription status (optional).
    public let status: String?
    /// Subscription priority (optional).
    public let priority: NSNumber?
    /// Custom subscription fields (optional) as NSDictionary.
    public let customFields: NSDictionary?
    /// Subscription categories (optional).
    public let cats: [String]?

    public init(resourceId: NSNumber,
                email: String,
                status: String? = nil,
                priority: NSNumber? = nil,
                customFields: NSDictionary? = nil,
                cats: [String]? = nil) {
        self.resourceId = resourceId
        self.email = email
        self.status = status
        self.priority = priority
        self.customFields = customFields
        self.cats = cats
        super.init()
    }

    /// Converts to Swift `EmailSubscription`.
    override internal func toSwift() -> (any Subscription)? {
        EmailSubscription(
            resourceId: resourceId.intValue,
            email: email,
            status: status,
            priority: priority?.intValue,
            customFields: mapNSDictionary(customFields),
            cats: cats
        )
    }
}

/// SMS channel subscription (ObjC bridge).
/// Mirrors Swift `SmsSubscription`: phone number + optional status/priority/custom fields/categories.
@objcMembers
public final class SmsSubscriptionObjC: SubscriptionObjC {
    /// Resource identifier.
    public let resourceId: NSNumber
    /// Phone number.
    public let phone: String
    /// Subscription status (optional).
    public let status: String?
    /// Subscription priority (optional).
    public let priority: NSNumber?
    /// Custom subscription fields (optional) as NSDictionary.
    public let customFields: NSDictionary?
    /// Subscription categories (optional).
    public let cats: [String]?

    public init(resourceId: NSNumber,
                phone: String,
                status: String? = nil,
                priority: NSNumber? = nil,
                customFields: NSDictionary? = nil,
                cats: [String]? = nil) {
        self.resourceId = resourceId
        self.phone = phone
        self.status = status
        self.priority = priority
        self.customFields = customFields
        self.cats = cats
        super.init()
    }

    /// Converts to Swift `SmsSubscription`.
    override internal func toSwift() -> (any Subscription)? {
        SmsSubscription(
            resourceId: resourceId.intValue,
            phone: phone,
            status: status,
            priority: priority?.intValue,
            customFields: mapNSDictionary(customFields),
            cats: cats
        )
    }
}

/// Push channel subscription (ObjC bridge).
/// Mirrors Swift `PushSubscription`: provider + subscriptionId + optional status/priority/custom fields/categories.
@objcMembers
public final class PushSubscriptionObjC: SubscriptionObjC {
    /// Resource identifier.
    public let resourceId: NSNumber
    /// Provider name (e.g., "ios-apns").
    public let provider: String
    /// Unique subscription ID.
    public let subscriptionId: String
    /// Subscription status (optional).
    public let status: String?
    /// Subscription priority (optional).
    public let priority: NSNumber?
    /// Custom subscription fields (optional) as NSDictionary.
    public let customFields: NSDictionary?
    /// Subscription categories (optional).
    public let cats: [String]?

    public init(resourceId: NSNumber,
                provider: String,
                subscriptionId: String,
                status: String? = nil,
                priority: NSNumber? = nil,
                customFields: NSDictionary? = nil,
                cats: [String]? = nil) {
        self.resourceId = resourceId
        self.provider = provider
        self.subscriptionId = subscriptionId
        self.status = status
        self.priority = priority
        self.customFields = customFields
        self.cats = cats
        super.init()
    }

    /// Converts to Swift `PushSubscription`.
    override internal func toSwift() -> (any Subscription)? {
        PushSubscription(
            resourceId: resourceId.intValue,
            provider: provider,
            subscriptionId: subscriptionId,
            status: status,
            priority: priority?.intValue,
            customFields: mapNSDictionary(customFields),
            cats: cats
        )
    }
}

/// Channel subscription with `cc_data` (ObjC bridge).
/// Mirrors Swift `CcDataSubscription`: arbitrary channel-specific data (e.g., chat ID).
@objcMembers
public final class CcDataSubscriptionObjC: SubscriptionObjC {
    /// Resource identifier.
    public let resourceId: NSNumber
    /// Channel type (e.g., "telegram_bot", "whatsapp").
    public let channel: String
    /// Channel-specific data (NSDictionary) mapped to `[String: JSONValue]`.
    public let ccData: NSDictionary
    /// Subscription status (optional).
    public let status: String?
    /// Subscription priority (optional).
    public let priority: NSNumber?
    /// Custom subscription fields (optional) as NSDictionary.
    public let customFields: NSDictionary?
    /// Subscription categories (optional).
    public let cats: [String]?

    public init(resourceId: NSNumber,
                channel: String,
                ccData: NSDictionary,
                status: String? = nil,
                priority: NSNumber? = nil,
                customFields: NSDictionary? = nil,
                cats: [String]? = nil) {
        self.resourceId = resourceId
        self.channel = channel
        self.ccData = ccData
        self.status = status
        self.priority = priority
        self.customFields = customFields
        self.cats = cats
        super.init()
    }

    /// Converts to Swift `CcDataSubscription`.
    override internal func toSwift() -> (any Subscription)? {
        CcDataSubscription(
            resourceId: resourceId.intValue,
            channel: channel,
            ccData: mapNSDictionary(ccData) ?? [:],
            status: status,
            priority: priority?.intValue,
            customFields: mapNSDictionary(customFields),
            cats: cats
        )
    }
}

/// NSDictionary -> [String: JSONValue]
private func mapNSDictionary(_ dict: NSDictionary?) -> [String: JSONValue]? {
    guard let dict else { return nil }
    var out: [String: JSONValue] = [:]
    for (k, v) in dict {
        guard let key = k as? String, let jv = toJSONValue(v) else { continue }
        out[key] = jv
    }
    return out
}

/// NSArray -> [JSONValue]
private func mapNSArray(_ arr: NSArray?) -> [JSONValue]? {
    guard let arr else { return nil }
    return arr.compactMap { toJSONValue($0) }
}

/// Any -> JSONValue (uses your enum as-is)
private func toJSONValue(_ any: Any?) -> JSONValue? {
    guard let any else { return .null }
    switch any {
    case is NSNull:
        return .null
    case let s as String:
        return .string(s)
    case let n as NSNumber:
        // Distinguish Bool from Number
        if CFGetTypeID(n) == CFBooleanGetTypeID() {
            return .bool(n.boolValue)
        }
        return .number(n.doubleValue)
    case let d as NSDictionary:
        return .object(mapNSDictionary(d) ?? [:])
    case let a as NSArray:
        return .array(mapNSArray(a) ?? [])
    case let s as [String: Any]:
        return .object(mapNSDictionary(s as NSDictionary) ?? [:])
    case let a as [Any]:
        return .array(mapNSArray(a as NSArray) ?? [])
    default:
        return nil
    }
}
