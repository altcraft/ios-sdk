//
//  SubscriptionModel.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Base protocol for all subscription types.
public protocol Subscription {}

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

    /// JSON coding keys for the parent model.
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

    /// JSON coding keys for the parent model.
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

    /// JSON coding keys for the parent model.
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

    /// JSON coding keys for the parent model.
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
