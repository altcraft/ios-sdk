//
//  InAppAnimatorImpl.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import UIKit

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Default `InAppAnimator` implementation for a specific view.
@available(iOSApplicationExtension, unavailable)
@MainActor
internal final class InAppAnimatorImpl: InAppAnimator {

    /// Campaign identifier associated with this animator.
    let companyId: Int

    /// Target in-app view.
    private weak var view: UIView?

    /// Creates animator for a specific in-app view.
    ///
    /// - Parameters:
    ///   - companyId: Campaign identifier.
    ///   - view: Target view.
    init(
        companyId: Int,
        view: UIView
    ) {
        self.companyId = companyId
        self.view = view
    }

    /// Applies immediate view changes without animation.
    func prepare(_ block: (UIView) -> Void) {
        guard let view else { return }
        block(view)
    }

    /// Runs UIKit animation for the target view.
    func animate(
        duration: TimeInterval,
        delay: TimeInterval = 0,
        options: UIView.AnimationOptions = [],
        animations: @escaping (UIView) -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard let view else {
            completion?(false)
            return
        }

        UIView.animate(
            withDuration: duration,
            delay: delay,
            options: options,
            animations: {
                animations(view)
            },
            completion: completion
        )
    }
}
