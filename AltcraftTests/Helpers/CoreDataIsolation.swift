//
//  CoreDataIsolation.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import CoreData
import ObjectiveC.runtime

private var _cdIsolationEnabled: Bool = false

/// Redirects Core Data stores to in-memory during tests.
enum CoreDataIsolation {
    /// Enable in-memory store swizzling.
    static func enable() {
        _cdIsolationEnabled = true
        _ = NSPersistentStoreCoordinator_Swizzle.shared
    }

    /// Disable swizzling and restore default behavior.
    static func disable() {
        _cdIsolationEnabled = false
    }
}

/// One-time swizzle for `addPersistentStore(...)`.
private final class NSPersistentStoreCoordinator_Swizzle {
    /// Triggers swizzling on first access.
    static let shared: NSPersistentStoreCoordinator_Swizzle = {
        let s = NSPersistentStoreCoordinator_Swizzle()
        s.swizzleAddPersistentStore()
        return s
    }()

    /// Swap original `addPersistentStore` with our alternative.
    private func swizzleAddPersistentStore() {
        let cls: AnyClass = NSPersistentStoreCoordinator.self

        let originalSel = #selector(NSPersistentStoreCoordinator.addPersistentStore(ofType:configurationName:at:options:))
        let swizzledSel = #selector(NSPersistentStoreCoordinator.alt_addPersistentStore(ofType:configurationName:at:options:))

        guard
            let originalMethod = class_getInstanceMethod(cls, originalSel),
            let swizzledMethod = class_getInstanceMethod(cls, swizzledSel)
        else { return }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

extension NSPersistentStoreCoordinator {
    /// Force `NSInMemoryStoreType` when isolation is enabled; otherwise call the original method.
    @objc func alt_addPersistentStore(
        ofType storeType: String,
        configurationName: String?,
        at url: URL?,
        options: [AnyHashable : Any]?
    ) throws -> NSPersistentStore {

        if _cdIsolationEnabled {
            return try self.alt_addPersistentStore(
                ofType: NSInMemoryStoreType,
                configurationName: configurationName,
                at: nil,
                options: nil
            )
        }

        return try self.alt_addPersistentStore(
            ofType: storeType,
            configurationName: configurationName,
            at: url,
            options: options
        )
    }
}

