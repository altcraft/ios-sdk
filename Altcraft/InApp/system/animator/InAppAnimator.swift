//
//  InAppAnimator.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import UIKit

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Provides animation hooks for a ready in-app view.
@available(iOSApplicationExtension, unavailable)
public protocol InAppAnimator {

    /// Campaign identifier associated with this animator.
    var companyId: Int { get }

    /// Applies immediate view changes without running animation.
    ///
    /// - Parameter block: View configuration block.
    @MainActor
    func prepare(_ block: (UIView) -> Void)

    /// Runs UIKit animation for the in-app view.
    ///
    /// - Parameters:
    ///   - duration: Animation duration.
    ///   - delay: Delay before animation starts.
    ///   - options: UIKit animation options.
    ///   - animations: Animation block.
    ///   - completion: Completion callback.
    @MainActor
    func animate(
        duration: TimeInterval,
        delay: TimeInterval,
        options: UIView.AnimationOptions,
        animations: @escaping (UIView) -> Void,
        completion: ((Bool) -> Void)?
    )
}
