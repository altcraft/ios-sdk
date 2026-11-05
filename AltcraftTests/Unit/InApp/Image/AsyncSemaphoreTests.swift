//
//  AsyncSemaphoreTests.swift
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
* AsyncSemaphoreTests
*
* Positive scenarios:
* - test_1: Initial permits equal to configured value.
* - test_2: Wait decreases available permits.
* - test_3: Signal increases available permits.
* - test_4: Wait suspends when no permits available.
* - test_5: Signal resumes suspended waiter.
* - test_6: Value less than 1 is normalized to 1.
* - test_7: Available permits are capped at max value.
*
* Edge scenarios:
* - test_8: Multiple waiters are resumed in FIFO order.
* - test_9: Signal with no waiters does not exceed max permits.
*
*/
final class AsyncSemaphoreTests: IsolatedTestCase {

    private func waitShort(_ seconds: TimeInterval = 0.02) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// test_1: Initial permits equal to configured value
    func test_1_initialPermits_equalConfiguredValue() async {
        let sem = AsyncSemaphore(value: 3)

        await sem.wait()
        await sem.wait()
        await sem.wait()

        let finished = Flag()

        let task = Task {
            await sem.wait()
            await finished.setTrue()
        }

        await waitShort(0.05)

        let value = await finished.value()
        XCTAssertFalse(value)

        task.cancel()
    }

    /// test_2: Wait decreases available permits
    func test_2_wait_decreasesPermits() async {
        let sem = AsyncSemaphore(value: 2)

        await sem.wait()
        await sem.wait()

        let finished = Flag()

        let task = Task {
            await sem.wait()
            await finished.setTrue()
        }

        await waitShort(0.05)

        let value = await finished.value()
        XCTAssertFalse(value)

        task.cancel()
    }

    /// test_3: Signal increases available permits
    func test_3_signal_releasesPermit() async {
        let sem = AsyncSemaphore(value: 1)

        await sem.wait()

        let finished = Flag()

        let task = Task {
            await sem.wait()
            await finished.setTrue()
        }

        await waitShort(0.02)

        let beforeSignal = await finished.value()
        XCTAssertFalse(beforeSignal)

        await sem.signal()
        await waitShort(0.05)

        let afterSignal = await finished.value()
        XCTAssertTrue(afterSignal)

        task.cancel()
    }

    /// test_4: Wait suspends when no permits available
    func test_4_wait_suspendsWhenNoPermits() async {
        let sem = AsyncSemaphore(value: 1)

        await sem.wait()

        let enteredSecond = Flag()

        let task = Task {
            await sem.wait()
            await enteredSecond.setTrue()
        }

        await waitShort(0.05)

        let value = await enteredSecond.value()
        XCTAssertFalse(value)

        task.cancel()
    }

    /// test_5: Signal resumes suspended waiter
    func test_5_signal_resumesSuspendedWaiter() async {
        let sem = AsyncSemaphore(value: 1)

        await sem.wait()

        let resumed = Flag()

        let task = Task {
            await sem.wait()
            await resumed.setTrue()
        }

        await waitShort(0.02)

        await sem.signal()
        await waitShort(0.05)

        let value = await resumed.value()
        XCTAssertTrue(value)

        task.cancel()
    }

    /// test_6: Value less than 1 is normalized to 1
    func test_6_valueLessThanOne_normalizedToOne() async {
        let sem = AsyncSemaphore(value: 0)

        await sem.wait()

        let suspended = Flag()

        let task = Task {
            await sem.wait()
            await suspended.setTrue()
        }

        await waitShort(0.05)

        let value = await suspended.value()
        XCTAssertFalse(value)

        task.cancel()
    }

    /// test_7: Available permits are capped at max value
    func test_7_permitsCappedAtMax() async {
        let sem = AsyncSemaphore(value: 2)

        await sem.signal()
        await sem.signal()
        await sem.signal()

        await sem.wait()
        await sem.wait()

        let thirdEntered = Flag()

        let task = Task {
            await sem.wait()
            await thirdEntered.setTrue()
        }

        await waitShort(0.05)

        let value = await thirdEntered.value()
        XCTAssertFalse(value)

        task.cancel()
    }

    /// test_8: Multiple waiters are resumed in FIFO order
    func test_8_multipleWaiters_fifoOrder() async {
        let sem = AsyncSemaphore(value: 1)

        await sem.wait()

        let order = OrderedInts()

        let task1 = Task {
            await sem.wait()
            await order.add(1)
        }

        await waitShort(0.01)

        let task2 = Task {
            await sem.wait()
            await order.add(2)
        }

        await waitShort(0.01)

        let task3 = Task {
            await sem.wait()
            await order.add(3)
        }

        await waitShort(0.01)

        await sem.signal()
        await waitShort(0.02)

        await sem.signal()
        await waitShort(0.02)

        await sem.signal()
        await waitShort(0.05)

        let values = await order.values()
        XCTAssertEqual(values, [1, 2, 3])

        task1.cancel()
        task2.cancel()
        task3.cancel()
    }

    /// test_9: Signal with no waiters does not exceed max permits
    func test_9_signalNoWaiters_doesNotExceedMax() async {
        let sem = AsyncSemaphore(value: 2)

        await sem.signal()
        await sem.signal()

        await sem.wait()
        await sem.wait()

        let suspended = Flag()

        let task = Task {
            await sem.wait()
            await suspended.setTrue()
        }

        await waitShort(0.05)

        let value = await suspended.value()
        XCTAssertFalse(value)

        task.cancel()
    }
}

private actor Flag {
    private var storage = false

    func setTrue() {
        storage = true
    }

    func value() -> Bool {
        storage
    }
}

private actor OrderedInts {
    private var storage: [Int] = []

    func add(_ value: Int) {
        storage.append(value)
    }

    func values() -> [Int] {
        storage
    }
}
