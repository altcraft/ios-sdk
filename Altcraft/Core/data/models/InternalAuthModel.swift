//
//  InternalAuthModel.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Internal authentication data resolved by the Core module.
@_spi(_Altcraft) public struct InternalAuthData: Sendable {
    public let currentAcid: String
    public let anonimAcid: String
    public let deviceId: String
    public let currentUserTag: String?
    public let startAnonSession: Int64
    public let isTest: Bool
}
