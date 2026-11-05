//
//  CoreDataIsolation.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import CoreData
import ObjectiveC.runtime
#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif
#if canImport(AltcraftPush)
@_spi(_Altcraft) import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@_spi(_Altcraft) import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@_spi(_Altcraft) import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@_spi(_Altcraft) import AltcraftTarget
#endif
#if canImport(AltcraftCore)
@testable import AltcraftCore
#endif
#if canImport(AltcraftPush)
@testable import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@testable import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@testable import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@testable import AltcraftTarget
#endif

/// Redirects every Core Data store in the test bundle to an in-memory store.
///
/// The SDK's `CoreDataManager.shared` is a process-wide singleton that would
/// otherwise open the real `Altcraft.sqlite` from disk. Under Xcode's parallel
/// test clones every worker process opens that same file, so asynchronous Core
/// Data activity (WAL checkpoints, persistent history, deferred saves) can
/// collide across processes and raise uncatchable Objective-C exceptions
/// (e.g. ClearCacheTests) or produce phantom "0.000 seconds" failures
/// (e.g. TargetEventTests). Using an in-memory store makes each process fully
/// independent and keeps every `useSDKCoreData` suite deterministic.
enum CoreDataIsolation {
    /// Installs (once) the in-memory redirect. Call it before the SDK Core
    /// Data stack is first touched.
    static func enable() {
        _ = NSPersistentStoreCoordinator_Swizzle.shared
    }

    /// No-op: the redirect is permanent for this test bundle.
    static func disable() {}
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
    /// Force `NSInMemoryStoreType` for every store loaded in the test bundle.
    @objc func alt_addPersistentStore(
        ofType storeType: String,
        configurationName: String?,
        at url: URL?,
        options: [AnyHashable: Any]?
    ) throws -> NSPersistentStore {

        return try self.alt_addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: configurationName,
            at: nil,
            options: nil
        )
    }
}
