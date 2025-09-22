//
//  BackgroundTasksTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import BackgroundTasks
import ObjectiveC.runtime
@testable import Altcraft

// MARK: - Captured hooks

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

// MARK: - Swizzled impls

/// - (BOOL)submitTaskRequest:(BGTaskRequest *)taskRequest error:(NSError **)error;
private typealias SubmitIMP = @convention(c) (AnyObject, Selector, AnyObject, UnsafeMutablePointer<NSError?>?) -> ObjCBool
private let swizzledSubmit: SubmitIMP = { _, _, request, errorPtr in
    BGHooks.submitCallCount += 1
    if let r = request as? BGAppRefreshTaskRequest {
        BGHooks.lastSubmittedRequest = r
    } else {
        BGHooks.lastSubmittedRequest = nil
    }
    if BGHooks.submitShouldFail {
        if let p = errorPtr {
            p.pointee = NSError(domain: "tests.bg.submit", code: 42,
                                userInfo: [NSLocalizedDescriptionKey: "submit failed"])
        }
        return false
    }
    return true
}

/// - (BOOL)registerForTaskWithIdentifier:(NSString *)identifier
///                           usingQueue:(dispatch_queue_t)queue
///                        launchHandler:(void (^)(BGTask *task))launchHandler;
private typealias RegisterIMP = @convention(c) (AnyObject, Selector, NSString, DispatchQueue?, @escaping (BGTask) -> Void) -> ObjCBool
private let swizzledRegister: RegisterIMP = { _, _, identifier, _, handler in
    BGHooks.registerCallCount += 1
    BGHooks.lastRegisteredIdentifier = identifier as String
    BGHooks.lastRegisteredHandler = handler
    return true
}

// MARK: - Global (fileprivate) storage for original IMPs (stubs if missing)

fileprivate var submitOrigIMPGlobal: IMP?
fileprivate var registerOrigIMPGlobal: IMP?

// MARK: - Swizzle helpers

private func swizzleBGTaskScheduler() {
    guard let cls: AnyClass = NSClassFromString("BGTaskScheduler") else { return }

    // submitTaskRequest:error:
    if let m = class_getInstanceMethod(cls, NSSelectorFromString("submitTaskRequest:error:")) {
        let newIMP = unsafeBitCast(swizzledSubmit as SubmitIMP, to: IMP.self)
        let orig = method_setImplementation(m, newIMP)
        submitOrigIMPGlobal = orig
    }

    // registerForTaskWithIdentifier:usingQueue:launchHandler:
    if let m = class_getInstanceMethod(cls, NSSelectorFromString("registerForTaskWithIdentifier:usingQueue:launchHandler:")) {
        let newIMP = unsafeBitCast(swizzledRegister as RegisterIMP, to: IMP.self)
        let orig = method_setImplementation(m, newIMP)
        registerOrigIMPGlobal = orig
    }
}

private func unswizzleBGTaskScheduler() {
    guard let cls: AnyClass = NSClassFromString("BGTaskScheduler") else { return }

    if let orig = submitOrigIMPGlobal,
       let m = class_getInstanceMethod(cls, NSSelectorFromString("submitTaskRequest:error:")) {
        method_setImplementation(m, orig)
    }

    if let orig = registerOrigIMPGlobal,
       let m = class_getInstanceMethod(cls, NSSelectorFromString("registerForTaskWithIdentifier:usingQueue:launchHandler:")) {
        method_setImplementation(m, orig)
    }
}

// MARK: - Tests

/**
 * BackgroundTasksTests (iOS 13+)
 *
 * Coverage:
 *  - test_1_registerBackgroundTask_registers_and_schedulesRetry
 *  - test_2_scheduleRetry_calls_submit_and_handles_errorPath (error path stubbed)
 *
 * Notes:
 *  - We don't execute the real background handler, only verify registration and scheduling.
 *  - No errorEvent hooking — we just simulate submit failure and assert the call path doesn't crash.
 */
final class BackgroundTasksTests: XCTestCase {

    override func setUp() {
        super.setUp()
        BGHooks.reset()
        swizzleBGTaskScheduler()
    }

    override func tearDown() {
        unswizzleBGTaskScheduler()
        super.tearDown()
    }

    /// test_1_registerBackgroundTask_registers_and_schedulesRetry
    func test_1_registerBackgroundTask_registers_and_schedulesRetry() {
        let svc = BackgroundTask()
        svc.registerBackgroundTask()

        XCTAssertEqual(BGHooks.registerCallCount, 1, "Should register exactly once")
        XCTAssertEqual(BGHooks.lastRegisteredIdentifier, Constants.BGTaskID)

        XCTAssertEqual(BGHooks.submitCallCount, 1, "Should schedule retry right after register()")
        let req = BGHooks.lastSubmittedRequest
        XCTAssertNotNil(req, "Must submit BGAppRefreshTaskRequest")
        XCTAssertEqual(req?.identifier, Constants.BGTaskID)

        // earliestBeginDate ~ now + 3 hours (±2 minutes)
        let threeHours: TimeInterval = 180 * 60
        let tol: TimeInterval = 120
        let delta = (req?.earliestBeginDate?.timeIntervalSinceNow ?? 0) - threeHours
        XCTAssertLessThan(abs(delta), tol, "earliestBeginDate must be about 3 hours ahead")
    }

    /// test_2_scheduleRetry_calls_submit_and_handles_errorPath
    func test_2_scheduleRetry_calls_submit_and_handles_errorPath() {
        let svc = BackgroundTask()

        // Success path
        BGHooks.submitShouldFail = false
        svc.scheduleRetry()
        XCTAssertEqual(BGHooks.submitCallCount, 1, "Submit should be called once (success)")

        // Error path (stubbed): should not crash, just another submit attempt
        BGHooks.submitShouldFail = true
        svc.scheduleRetry()
        XCTAssertEqual(BGHooks.submitCallCount, 2, "Submit should be called again (failure path)")
        // We purposely don't assert errorEvent; this is a stub.
    }
}

