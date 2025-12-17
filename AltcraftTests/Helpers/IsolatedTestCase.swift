import XCTest
import CoreData
@testable import Altcraft

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

    /// Use SDK Core Data container instead of isolated in-memory one.
    class var useSDKCoreData: Bool { false }

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

        // 4) isolate CoreData
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
