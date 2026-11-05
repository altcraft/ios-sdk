//
//  PushSubscribeQueues.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Queues used by the push subscription subsystem.
enum PushSubscribeQueues {

    /// Serial queue for public subscribe commands in call order.
    static let entityQueue = SerialCommandQueue(
        label: "com.altcraft.push.subscribe.entityQueue",
        usesEpoch: false
    )

    /// Serial queue for starting subscription processing.
    static let startQueue = SerialCommandQueue(
        label: "com.altcraft.push.subscribe.startQueue",
        usesEpoch: true
    )
}
