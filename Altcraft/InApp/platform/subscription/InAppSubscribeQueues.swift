//
//  InAppSubscribeQueues.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Queues used by the in-app subscription subsystem.
enum InAppSubscribeQueues {

    /// Serial queue for public subscribe commands in call order.
    static let entityQueue = SerialCommandQueue(
        label: "com.altcraft.inapp.subscribe.entityQueue",
        usesEpoch: false
    )

    /// Serial queue for starting subscription processing.
    static let startQueue = SerialCommandQueue(
        label: "com.altcraft.inapp.subscribe.startQueue",
        usesEpoch: true
    )
}
