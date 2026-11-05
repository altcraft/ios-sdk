//
//  InAppTopViewControllerResolver.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import UIKit

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Resolves the currently visible top view controller.
@available(iOSApplicationExtension, unavailable)
internal enum InAppTopViewControllerResolver {

    /// Returns the topmost view controller from the active window hierarchy.
    ///
    /// The method walks through navigation controllers, tab controllers,
    /// and presented view controllers until it finds the visible controller.
    ///
    /// - Parameter base: Optional starting view controller.
    /// - Returns: Topmost visible view controller, or `nil` if unavailable.
    @MainActor
    static func topViewController(
        base: UIViewController? = nil
    ) -> UIViewController? {
        let root: UIViewController?

        if let base {
            root = base
        } else {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }

            let keyWindow = scenes
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }

            root = keyWindow?.rootViewController
        }

        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }

        if let tab = root as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }

        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }

        return root
    }
}
