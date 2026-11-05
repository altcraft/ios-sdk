//
//  UTM.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// UTM campaign-attribution parameters, attached to a target event.
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
