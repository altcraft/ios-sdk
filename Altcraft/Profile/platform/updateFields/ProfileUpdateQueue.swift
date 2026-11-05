//
//  ProfileUpdateQueue.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Centralized queues for profile updates.
enum ProfileUpdateQueues {
    /// Serial queue for public profile update commands in call order.
    static let entityQueue = SerialCommandQueue(
        label: ProfileConstants.Queues.profileUpdateEntityQueue,
        usesEpoch: true
    )

    /// Serial queue for starting profile update processing.
    static let startQueue = SerialCommandQueue(
        label: ProfileConstants.Queues.profileUpdateStartQueue,
        usesEpoch: true
    )
}
