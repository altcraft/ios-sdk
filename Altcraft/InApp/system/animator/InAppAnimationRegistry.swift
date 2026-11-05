//
//  InAppAnimationRegistry.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Actor-based registry for in-app notification animation callbacks.
///
/// Stores a single main-actor listener used to receive `InAppAnimator` instances
/// when an in-app notification needs to be animated.
@available(iOSApplicationExtension, unavailable)
internal actor InAppAnimationRegistry {

    /// Shared singleton instance.
    static let shared = InAppAnimationRegistry()

    /// Current animation listener.
    private var listener: (@MainActor (InAppAnimator) -> Void)?

    /// Updates the current animation listener.
    ///
    /// - Parameter listener: Closure called on the main actor with an
    ///   `InAppAnimator`, or `nil` to remove the current listener.
    func setListener(
        _ listener: (@MainActor (InAppAnimator) -> Void)?
    ) {
        self.listener = listener
    }

    /// Returns the current animation listener.
    ///
    /// - Returns: Closure called on the main actor with an `InAppAnimator`,
    ///   or `nil` if no listener is registered.
    func getListener() -> (@MainActor (InAppAnimator) -> Void)? {
        listener
    }
}
