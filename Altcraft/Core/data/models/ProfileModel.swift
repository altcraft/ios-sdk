//
//  ProfileModel.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

/// User profile payload, including status and subscription details.
public struct ProfileData: Codable, Sendable {
    public let id: String?
    public let status: String?
    public let acid: String?
    public let isTest: Bool?
    public let subscription: SubscriptionData?

    /// JSON coding keys for the parent model.
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case acid
        case isTest = "is_test"
        case subscription
    }
}

/// Subscription payload including provider, fields, and categories.
public struct SubscriptionData: Codable, Sendable {
    public let subscriptionId: String?
    public let hashId: String?
    public let provider: String?
    public let status: String?
    public let fields: [String: JSONValue]?
    public let cats: [CategoryData]?

    /// JSON coding keys for the parent model.
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
public struct CategoryData: Codable, Sendable {
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
