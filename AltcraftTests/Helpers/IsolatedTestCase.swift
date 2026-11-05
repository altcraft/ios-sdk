//
//  IsolatedTestCase.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import AltcraftCore
@_spi(_Altcraft) import AltcraftCore
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

/// Base test case isolating UserDefaults and Core Data.
class IsolatedTestCase: XCTestCase {

    // MARK: - Global test mutex (serializes all tests inheriting this class)
    private static let globalMutex = TestMutex()

    // MARK: - UserDefaults isolation
    private(set) var udSandbox: UserDefaultsSandbox!
    var defaults: UserDefaults { udSandbox.defaults }

    // MARK: - Core Data isolation
    private(set) var core: TestCoreDataStack!
    var viewContext: NSManagedObjectContext { core.viewContext }

    /// Returns a new background context.
    func newBGContext() -> NSManagedObjectContext { core.newBGContext() }

    /// Use the SDK's Core Data container (`CoreDataManager.shared`) instead of
    /// a private in-memory container. In this bundle the SDK container still
    /// loads an in-memory store (see `CoreDataIsolation`), so it is isolated
    /// per process while exercising the SDK's real query paths.
    class var useSDKCoreData: Bool { false }

    /// The SDK container to proxy in `useSDKCoreData` mode. Override to target
    /// a specific module manager (e.g. `pushDatabase.persistentContainer`).
    class var sdkManagerContainer: NSPersistentContainer? {
        CoreDataManager.shared.persistentContainer
    }

    class var modelName: String? { nil }
    class var frameworkBundleIdentifier: String? { nil }
    class var frameworkBundleToken: AnyClass { AltcraftSDK.self }

    // MARK: - XCTest lifecycle

    /// Set up isolated stores before each test.
    override func setUpWithError() throws {
        // 1) serialize tests
        Self.globalMutex.lock()

        // 2) call super
        try super.setUpWithError()

        // 3) isolate UserDefaults
        udSandbox = UserDefaultsSandbox()
        UserDefaultsIsolation.enable(with: udSandbox.defaults)

        // 4) isolate CoreData:
        //    install the in-memory redirect before any SDK store load so the
        //    process-wide `CoreDataManager.shared` never touches the shared
        //    on-disk `Altcraft.sqlite` (parallel clones would race on the file).
        CoreDataIsolation.enable()

        if Self.useSDKCoreData {
            core = TestCoreDataStack(mode: .sdkManager(Self.sdkManagerContainer))
        } else {
            core = TestCoreDataStack(
                modelName: Self.modelName,
                bundleToken: Self.frameworkBundleToken,
                bundleIdentifier: Self.frameworkBundleIdentifier
            )
        }
    }

    /// Resets the process-wide configuration caches before each test so a
    /// test never observes a configuration persisted by a previous test,
    /// class, or the host application's own SDK initialization.
    ///
    /// Runs on the async `setUp()` path (not the sync `setUpWithError()`)
    /// so the cache resets never block the main thread: the SDK containers
    /// may still be loading lazily at this point, and blocking the main
    /// thread while a background task loads them would deadlock.
    override func setUp() async throws {
        try await super.setUp()

        await ConfigManager.shared.clearCache()
        await PushConfigManager.shared.clearCache()
        await InAppConfigManager.shared.clearCache()
    }

    /// Tear down isolated stores after each test.
    override func tearDownWithError() throws {
        // unlock must happen even if something fails while tearing down
        defer { Self.globalMutex.unlock() }

        if !Self.useSDKCoreData {
            CoreDataIsolation.disable()
        }
        UserDefaultsIsolation.disable()

        udSandbox?.clear()
        core?.wipe()

        udSandbox = nil
        core = nil

        try super.tearDownWithError()
    }
}
