//
//  IsolatedTestCase.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//  © 2025 Altcraft. All rights reserved.
//

import XCTest
import CoreData
@testable import Altcraft

class IsolatedTestCase: XCTestCase {
    private(set) var udSandbox: UserDefaultsSandbox!
    var defaults: UserDefaults { udSandbox.defaults }

    private(set) var core: TestCoreDataStack!
    var viewContext: NSManagedObjectContext { core.viewContext }
    func newBGContext() -> NSManagedObjectContext { core.newBGContext() }

    // MARK: - Customization points for subclasses

    /// If true, tests use CoreDataManager.shared.persistentContainer (SDK container).
    /// Default is false -> isolated in-memory container (legacy behavior).
    class var useSDKCoreData: Bool { false }

    class var modelName: String? { nil }
    class var frameworkBundleIdentifier: String? { nil }
    class var frameworkBundleToken: AnyClass { AltcraftSDK.self }

    override func setUpWithError() throws {
        try super.setUpWithError()

        udSandbox = UserDefaultsSandbox()
        UserDefaultsIsolation.enable(with: udSandbox.defaults)

        if Self.useSDKCoreData {
            // Use the same container as production code; do NOT enable CoreDataIsolation (keeps SQLite)
            core = TestCoreDataStack(mode: .sdkPersistent)
        } else {
            // Legacy isolated in-memory stack + CoreDataIsolation swizzle
            core = TestCoreDataStack(
                modelName: Self.modelName,
                bundleToken: Self.frameworkBundleToken,
                bundleIdentifier: Self.frameworkBundleIdentifier
            )
            CoreDataIsolation.enable()
        }
    }

    override func tearDownWithError() throws {
        if !Self.useSDKCoreData {
            CoreDataIsolation.disable()
        }
        UserDefaultsIsolation.disable()

        udSandbox.clear()
        core.wipe()

        udSandbox = nil
        core = nil

        try super.tearDownWithError()
    }
}
