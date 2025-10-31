//
//  UserDefaultsIsolation.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//  © 2025 Altcraft. All rights reserved.
//

import Foundation
import ObjectiveC.runtime

private var _udIsolationEnabled: Bool = false
private var _udCurrentSuite: UserDefaults? = nil

/// Redirects `UserDefaults.standard` to a provided suite during tests.
enum UserDefaultsIsolation {
    /// Enable isolation with a specific `UserDefaults` suite.
    static func enable(with defaults: UserDefaults) {
        _udCurrentSuite = defaults
        _udIsolationEnabled = true
        _ = Swizzler.shared
    }

    /// Disable isolation and restore default behavior.
    static func disable() {
        _udIsolationEnabled = false
        _udCurrentSuite = nil
    }
}

/// Performs one-time swizzling of `UserDefaults.standard`.
private final class Swizzler {
    /// Singleton that triggers swizzling on first access.
    static let shared: Swizzler = {
        let s = Swizzler()
        s.swizzleStandardUserDefaults()
        return s
    }()

    private var originalImp: IMP?

    /// Swap `standardUserDefaults` with `alt_standardUserDefaults`.
    private func swizzleStandardUserDefaults() {
        let cls: AnyClass = UserDefaults.self
        guard let meta = object_getClass(cls) else { return }

        let originalSel = NSSelectorFromString("standardUserDefaults")
        let swizzledSel = #selector(UserDefaults.alt_standardUserDefaults)

        guard
            let originalMethod = class_getClassMethod(meta, originalSel),
            let swizzledMethod = class_getClassMethod(meta, swizzledSel)
        else { return }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

extension UserDefaults {
    /// Replacement for `UserDefaults.standard` used when isolation is enabled.
    @objc class func alt_standardUserDefaults() -> UserDefaults {
        if _udIsolationEnabled, let d = _udCurrentSuite {
            return d
        }
        return self.alt_standardUserDefaults()
    }
}
