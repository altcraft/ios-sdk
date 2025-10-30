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

enum UserDefaultsIsolation {
    static func enable(with defaults: UserDefaults) {
        _udCurrentSuite = defaults
        _udIsolationEnabled = true
        _ = Swizzler.shared
    }

    static func disable() {
        _udIsolationEnabled = false
        _udCurrentSuite = nil
    }
}

private final class Swizzler {
    static let shared: Swizzler = {
        let s = Swizzler()
        s.swizzleStandardUserDefaults()
        return s
    }()

    private var originalImp: IMP?

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
    @objc class func alt_standardUserDefaults() -> UserDefaults {
        if _udIsolationEnabled, let d = _udCurrentSuite {
            return d
        }
        return self.alt_standardUserDefaults()
    }
}

