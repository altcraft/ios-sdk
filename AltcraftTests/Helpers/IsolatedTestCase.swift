import XCTest
import CoreData
@testable import Altcraft

/// Base test case isolating UserDefaults and Core Data.
class IsolatedTestCase: XCTestCase {
    private(set) var udSandbox: UserDefaultsSandbox!
    var defaults: UserDefaults { udSandbox.defaults }

    private(set) var core: TestCoreDataStack!
    var viewContext: NSManagedObjectContext { core.viewContext }

    /// Returns a new background context.
    func newBGContext() -> NSManagedObjectContext { core.newBGContext() }

    /// Use SDK Core Data container instead of isolated in-memory one.
    class var useSDKCoreData: Bool { false }

    class var modelName: String? { nil }
    class var frameworkBundleIdentifier: String? { nil }
    class var frameworkBundleToken: AnyClass { AltcraftSDK.self }

    /// Set up isolated stores before each test.
    override func setUpWithError() throws {
        try super.setUpWithError()

        udSandbox = UserDefaultsSandbox()
        UserDefaultsIsolation.enable(with: udSandbox.defaults)

        if Self.useSDKCoreData {
            core = TestCoreDataStack(mode: .sdkPersistent)
        } else {
            core = TestCoreDataStack(
                modelName: Self.modelName,
                bundleToken: Self.frameworkBundleToken,
                bundleIdentifier: Self.frameworkBundleIdentifier
            )
            CoreDataIsolation.enable()
        }
    }

    /// Tear down isolated stores after each test.
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
