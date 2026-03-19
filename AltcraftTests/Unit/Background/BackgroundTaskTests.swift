//
//  BackgroundTaskTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2026 Altcraft. All rights reserved.
//

import XCTest
import BackgroundTasks
import ObjectiveC.runtime
@testable import Altcraft

/**
 * BackgroundTaskTests
 *
 * Positive scenarios:
 *  - test_1: registerBackgroundTask → registers with correct identifier and schedules retry after 3 hours.
 *  - test_2: scheduleRetry → calls submit for both success and error paths.
 *
 */
final class BackgroundTaskTests: IsolatedTestCase {

    override func setUp() {
        super.setUp()
        BGHooks.reset()
        swizzleBGTaskScheduler()
    }

    override func tearDown() {
        unswizzleBGTaskScheduler()
        super.tearDown()
    }

    /// test_1: registerBackgroundTask registers with correct identifier and schedules retry after 3 hours
    func test_1_registerBackgroundTask_registersWithCorrectIdentifier_andSchedulesRetryAfterThreeHours() {
        let service = BackgroundTask.shared

        service.registerBackgroundTask()

        XCTAssertEqual(BGHooks.registerCallCount, 1)
        XCTAssertEqual(BGHooks.lastRegisteredIdentifier, TestConstants.bgTaskID)

        XCTAssertEqual(BGHooks.submitCallCount, 1)

        let request = BGHooks.lastSubmittedRequest
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.identifier, TestConstants.bgTaskID)

        verifyEarliestBeginDateIsApproximatelyThreeHours(from: request)
    }

    /// test_2: scheduleRetry calls submit for both success and error paths
    func test_2_scheduleRetry_callsSubmit_forBothSuccessAndErrorPaths() {
        let service = BackgroundTask.shared

        BGHooks.submitShouldFail = false
        service.scheduleRetry()
        XCTAssertEqual(BGHooks.submitCallCount, 1)

        BGHooks.submitShouldFail = true
        service.scheduleRetry()
        XCTAssertEqual(BGHooks.submitCallCount, 2)
    }
}

private extension BackgroundTaskTests {

    func verifyEarliestBeginDateIsApproximatelyThreeHours(
        from request: BGAppRefreshTaskRequest?
    ) {
        guard let earliestBeginDate = request?.earliestBeginDate else {
            XCTFail("Earliest begin date should not be nil")
            return
        }

        let expectedTimeInterval = TestConstants.threeHoursInSeconds
        let actualTimeInterval = earliestBeginDate.timeIntervalSinceNow
        let timeDifference = abs(actualTimeInterval - expectedTimeInterval)

        XCTAssertLessThan(timeDifference, TestConstants.toleranceInSeconds)
    }
}

private enum TestConstants {
    static let bgTaskID = Constants.BGTaskID
    static let errorDomain = "tests.bg.submit"
    static let errorCode = 42
    static let errorDescription = "submit failed"
    static let threeHoursInSeconds: TimeInterval = 180 * 60
    static let toleranceInSeconds: TimeInterval = 120

    enum Selectors {
        static let submitTaskRequest = NSSelectorFromString(
            "submitTaskRequest:error:"
        )

        static let registerForTask = NSSelectorFromString(
            "registerForTaskWithIdentifier:usingQueue:launchHandler:"
        )
    }

    enum ClassNames {
        static let bgTaskScheduler = "BGTaskScheduler"
    }
}

private enum BGHooks {
    static var registerCallCount = 0
    static var lastRegisteredIdentifier: String?
    static var lastRegisteredHandler: ((BGTask) -> Void)?

    static var submitCallCount = 0
    static var lastSubmittedRequest: BGAppRefreshTaskRequest?
    static var submitShouldFail = false

    static func reset() {
        registerCallCount = 0
        lastRegisteredIdentifier = nil
        lastRegisteredHandler = nil
        submitCallCount = 0
        lastSubmittedRequest = nil
        submitShouldFail = false
    }
}

private typealias SubmitIMP = @convention(c) (
    AnyObject,
    Selector,
    AnyObject,
    UnsafeMutablePointer<NSError?>?
) -> ObjCBool

private let swizzledSubmit: SubmitIMP = { _, _, request, errorPtr in
    BGHooks.submitCallCount += 1

    if let refreshRequest = request as? BGAppRefreshTaskRequest {
        BGHooks.lastSubmittedRequest = refreshRequest
    } else {
        BGHooks.lastSubmittedRequest = nil
    }

    if BGHooks.submitShouldFail {
        errorPtr?.pointee = NSError(
            domain: TestConstants.errorDomain,
            code: TestConstants.errorCode,
            userInfo: [NSLocalizedDescriptionKey: TestConstants.errorDescription]
        )
        return false
    }

    return true
}

private typealias RegisterIMP = @convention(c) (
    AnyObject,
    Selector,
    NSString,
    DispatchQueue?,
    @escaping (BGTask) -> Void
) -> ObjCBool

private let swizzledRegister: RegisterIMP = { _, _, identifier, _, handler in
    BGHooks.registerCallCount += 1
    BGHooks.lastRegisteredIdentifier = identifier as String
    BGHooks.lastRegisteredHandler = handler
    return true
}

private var submitOrigIMPGlobal: IMP?
private var registerOrigIMPGlobal: IMP?

private func swizzleBGTaskScheduler() {
    guard let schedulerClass = NSClassFromString(
        TestConstants.ClassNames.bgTaskScheduler
    ) else {
        return
    }

    swizzleSubmitTaskRequest(in: schedulerClass)
    swizzleRegisterForTask(in: schedulerClass)
}

private func swizzleSubmitTaskRequest(in `class`: AnyClass) {
    guard let method = class_getInstanceMethod(
        `class`,
        TestConstants.Selectors.submitTaskRequest
    ) else {
        return
    }

    let newIMP = unsafeBitCast(swizzledSubmit as SubmitIMP, to: IMP.self)
    let originalIMP = method_setImplementation(method, newIMP)
    submitOrigIMPGlobal = originalIMP
}

private func swizzleRegisterForTask(in `class`: AnyClass) {
    guard let method = class_getInstanceMethod(
        `class`,
        TestConstants.Selectors.registerForTask
    ) else {
        return
    }

    let newIMP = unsafeBitCast(swizzledRegister as RegisterIMP, to: IMP.self)
    let originalIMP = method_setImplementation(method, newIMP)
    registerOrigIMPGlobal = originalIMP
}

private func unswizzleBGTaskScheduler() {
    guard let schedulerClass = NSClassFromString(
        TestConstants.ClassNames.bgTaskScheduler
    ) else {
        return
    }

    restoreOriginalImplementation(
        for: schedulerClass,
        selector: TestConstants.Selectors.submitTaskRequest,
        originalIMP: submitOrigIMPGlobal
    )

    restoreOriginalImplementation(
        for: schedulerClass,
        selector: TestConstants.Selectors.registerForTask,
        originalIMP: registerOrigIMPGlobal
    )
}

private func restoreOriginalImplementation(
    for `class`: AnyClass,
    selector: Selector,
    originalIMP: IMP?
) {
    guard let originalIMP,
          let method = class_getInstanceMethod(`class`, selector) else {
        return
    }

    method_setImplementation(method, originalIMP)
}
