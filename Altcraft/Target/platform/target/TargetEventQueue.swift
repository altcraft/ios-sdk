//
//  TargetEventQueue.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Centralized queues for mobile events.
enum TargetEventQueues {
    /// Serial queue for public mobile event commands in call order.
    static let entityQueue = SerialCommandQueue(
        label: TargetConstants.Queues.targetEventEntityQueue,
        usesEpoch: true
    )

    /// Serial queue for starting mobile event processing.
    static let startQueue = SerialCommandQueue(
        label: TargetConstants.Queues.targetEventStartQueue,
        usesEpoch: true
    )
}
