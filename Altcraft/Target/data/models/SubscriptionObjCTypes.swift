//
//  SubscriptionObjCTypes.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Base ObjC-visible subscription type.
/// Subclasses must convert themselves to a concrete Swift `Subscription` via `toSwift()`.
@objcMembers
public class SubscriptionObjC: NSObject {
    /// SDK bridge (not exposed to ObjC callers).
    public func toSwift() -> (any Subscription)? { nil }
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
    override public func toSwift() -> (any Subscription)? {
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
    override public func toSwift() -> (any Subscription)? {
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
    override public func toSwift() -> (any Subscription)? {
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
    override public func toSwift() -> (any Subscription)? {
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

// MARK: - NSDictionary mapping helpers

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

/// Any -> JSONValue (uses Core's `JSONValue` enum as-is)
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
