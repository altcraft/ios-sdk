//
//  ModuleLogPrefixTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
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

/**
 * ModuleLogPrefixTests
 *
 * Verifies that each module's `Log` facade prefixes the event function with
 * its module-specific `MODULE_PREFIX` tag (mirrors Android parity).
 *
 * Positive scenarios:
 *  - test_1: PushLog.event emits an Event whose function starts with "[altcraft-push] ".
 *  - test_2: PushLog.error emits an ErrorEvent whose function starts with "[altcraft-push] ".
 *  - test_3: PushLog.retry emits a RetryEvent whose function starts with "[altcraft-push] ".
 *  - test_4: InAppLog.event emits an Event whose function starts with "[altcraft-inapp] ".
 *  - test_5: InAppLog.error emits an ErrorEvent whose function starts with "[altcraft-inapp] ".
 *  - test_6: InAppLog.retry emits a RetryEvent whose function starts with "[altcraft-inapp] ".
 *  - test_7: ProfileLog.error emits an ErrorEvent whose function starts with "[altcraft-profile] ".
 *  - test_8: ProfileLog.retry emits a RetryEvent whose function starts with "[altcraft-profile] ".
 *  - test_9: TargetLog.error emits an ErrorEvent whose function starts with "[altcraft-target] ".
 *  - test_10: TargetLog.retry emits a RetryEvent whose function starts with "[altcraft-target] ".
 *  - test_11: CoreLog.event emits an Event whose function starts with "[altcraft-core] ".
 *  - test_12: CoreLog.error emits an ErrorEvent whose function starts with "[altcraft-core] ".
 *  - test_13: CoreLog.retry emits a RetryEvent whose function starts with "[altcraft-core] ".
 */
final class ModuleLogPrefixTests: IsolatedTestCase {

    override func setUp() {
        super.setUp()
        SDKEvents.shared.unsubscribe()
    }

    override func tearDown() {
        SDKEvents.shared.unsubscribe()
        super.tearDown()
    }

    // MARK: - Push

    /// test_1: PushLog.event prefixes function with "[altcraft-push] ".
    func test_1_pushEvent_hasPrefix() {
        let ev = PushLog.event(
            "pushSubscribe",
            event: PushModuleEvents.pushProviderSet
        )
        XCTAssertTrue(
            ev.function.hasPrefix("[altcraft-push] pushSubscribe"),
            "Expected function to start with \"[altcraft-push] pushSubscribe\", got \"\(ev.function)\""
        )
    }

    /// test_2: PushLog.error prefixes function with "[altcraft-push] ".
    func test_2_pushError_hasPrefix() {
        let ev = PushLog.error(
            "pushSubscribe",
            error: PushModuleEvents.pushSubscribeRequestFailed
        )
        XCTAssertTrue(
            ev.function.hasPrefix("[altcraft-push] pushSubscribe"),
            "Expected function to start with \"[altcraft-push] pushSubscribe\", got \"\(ev.function)\""
        )
    }

    /// test_3: PushLog.retry prefixes function with "[altcraft-push] ".
    func test_3_pushRetry_hasPrefix() {
        let ev = PushLog.retry(
            "pushSubscribe",
            error: PushModuleEvents.subscribeRequestDataIsNil
        )
        XCTAssertTrue(
            ev.function.hasPrefix("[altcraft-push] pushSubscribe"),
            "Expected function to start with \"[altcraft-push] pushSubscribe\", got \"\(ev.function)\""
        )
    }

    // MARK: - InApp

    /// test_4: InAppLog.event prefixes function with "[altcraft-inapp] ".
    func test_4_inAppEvent_hasPrefix() {
        let ev = InAppLog.event(
            "inAppSubscribe",
            event: InAppModuleEvents.inAppSubscribeRequestSuccessful
        )
        XCTAssertTrue(
            ev.function.hasPrefix("[altcraft-inapp] inAppSubscribe"),
            "Expected function to start with \"[altcraft-inapp] inAppSubscribe\", got \"\(ev.function)\""
        )
    }

    /// test_5: InAppLog.error prefixes function with "[altcraft-inapp] ".
    func test_5_inAppError_hasPrefix() {
        let ev = InAppLog.error(
            "inAppSubscribe",
            error: InAppModuleEvents.inAppSubscribeRequestFailed
        )
        XCTAssertTrue(
            ev.function.hasPrefix("[altcraft-inapp] inAppSubscribe"),
            "Expected function to start with \"[altcraft-inapp] inAppSubscribe\", got \"\(ev.function)\""
        )
    }

    /// test_6: InAppLog.retry prefixes function with "[altcraft-inapp] ".
    func test_6_inAppRetry_hasPrefix() {
        let ev = InAppLog.retry(
            "inAppSubscribe",
            error: InAppModuleEvents.subscribeRequestDataIsNil
        )
        XCTAssertTrue(
            ev.function.hasPrefix("[altcraft-inapp] inAppSubscribe"),
            "Expected function to start with \"[altcraft-inapp] inAppSubscribe\", got \"\(ev.function)\""
        )
    }

    // MARK: - Profile

    /// test_7: ProfileLog.error prefixes function with "[altcraft-profile] ".
    func test_7_profileError_hasPrefix() {
        let ev = ProfileLog.error(
            "profileUpdate",
            error: ProfileModuleEvents.profileUpdateRequestDataIsNil
        )
        XCTAssertTrue(
            ev.function.hasPrefix("[altcraft-profile] profileUpdate"),
            "Expected function to start with \"[altcraft-profile] profileUpdate\", got \"\(ev.function)\""
        )
    }

    /// test_8: ProfileLog.retry prefixes function with "[altcraft-profile] ".
    func test_8_profileRetry_hasPrefix() {
        let ev = ProfileLog.retry(
            "profileUpdate",
            error: ProfileModuleEvents.profileUpdateRequestDataIsNil
        )
        XCTAssertTrue(
            ev.function.hasPrefix("[altcraft-profile] profileUpdate"),
            "Expected function to start with \"[altcraft-profile] profileUpdate\", got \"\(ev.function)\""
        )
    }

    // MARK: - Target

    /// test_9: TargetLog.error prefixes function with "[altcraft-target] ".
    func test_9_targetError_hasPrefix() {
        let ev = TargetLog.error(
            "mobileEvent",
            error: TargetModuleEvents.mobileRequestDataIsNil
        )
        XCTAssertTrue(
            ev.function.hasPrefix("[altcraft-target] mobileEvent"),
            "Expected function to start with \"[altcraft-target] mobileEvent\", got \"\(ev.function)\""
        )
    }

    /// test_10: TargetLog.retry prefixes function with "[altcraft-target] ".
    func test_10_targetRetry_hasPrefix() {
        let ev = TargetLog.retry(
            "mobileEvent",
            error: TargetModuleEvents.mobileRequestDataIsNil
        )
        XCTAssertTrue(
            ev.function.hasPrefix("[altcraft-target] mobileEvent"),
            "Expected function to start with \"[altcraft-target] mobileEvent\", got \"\(ev.function)\""
        )
    }

    // MARK: - Core

    /// test_11: CoreLog.event prefixes function with "[altcraft-core] ".
    func test_11_coreEvent_hasPrefix() {
        let ev = CoreLog.event(
            "configSet",
            event: CoreEvents.configSet
        )
        XCTAssertTrue(
            ev.function.hasPrefix("[altcraft-core] configSet"),
            "Expected function to start with \"[altcraft-core] configSet\", got \"\(ev.function)\""
        )
    }

    /// test_12: CoreLog.error prefixes function with "[altcraft-core] ".
    func test_12_coreError_hasPrefix() {
        let ev = CoreLog.error(
            "configIsNotSet",
            error: CoreEvents.configIsNotSet
        )
        XCTAssertTrue(
            ev.function.hasPrefix("[altcraft-core] configIsNotSet"),
            "Expected function to start with \"[altcraft-core] configIsNotSet\", got \"\(ev.function)\""
        )
    }

    /// test_13: CoreLog.retry prefixes function with "[altcraft-core] ".
    func test_13_coreRetry_hasPrefix() {
        let ev = CoreLog.retry(
            "configIsNotSet",
            error: CoreEvents.configIsNotSet
        )
        XCTAssertTrue(
            ev.function.hasPrefix("[altcraft-core] configIsNotSet"),
            "Expected function to start with \"[altcraft-core] configIsNotSet\", got \"\(ev.function)\""
        )
    }
}
