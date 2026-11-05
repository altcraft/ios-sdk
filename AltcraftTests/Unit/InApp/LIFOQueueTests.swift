//
//  LIFOQueueTests.swift
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
* LIFOQueueTests
*
* Positive scenarios:
* - test_1: LIFO order, last added is processed first.
* - test_2: Sequential processing of all items.
* - test_3: MaxSize evicts oldest item.
* - test_4: RemoveAll clears pending items.
* - test_5: Count returns current pending queue size.
* - test_6: Error in processing does not stop queue.
* - test_7: Worker processes new items added during processing.
*
* Edge scenarios:
* - test_8: CancelWorker cancels current worker.
* - test_9: IsWorkerRunning returns correct state while processing.
* - test_10: Single item processes correctly.
*
*/
final class LIFOQueueTests: IsolatedTestCase {

    private func waitShort(_ seconds: TimeInterval = 0.05) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// test_1: LIFO order, last added is processed first
    func test_1_lifoOrder() async {
        let order = OrderedInts()

        let queue = LIFOQueue<Int>(
            functionName: "test_1",
            maxSize: 10,
            initAwait: false,
            placementAwait: false
        ) { item in
            await order.add(item)
        }

        await queue.add(1)
        await queue.add(2)
        await queue.add(3)

        await waitShort(0.3)

        let values = await order.values()
        XCTAssertEqual(values, [3, 2, 1])
    }

    /// test_2: Sequential processing of all items
    func test_2_sequentialProcessing() async {
        let processed = Counter()

        let queue = LIFOQueue<Int>(
            functionName: "test_2",
            maxSize: 10,
            initAwait: false,
            placementAwait: false
        ) { _ in
            await self.waitShort(0.02)
            await processed.increment()
        }

        for i in 1...5 {
            await queue.add(i)
        }

        await waitShort(0.5)

        let value = await processed.value()
        XCTAssertEqual(value, 5)
    }

    /// test_3: MaxSize evicts oldest item
    func test_3_maxSize_evictsOldest() async {
        let order = OrderedInts()

        let queue = LIFOQueue<Int>(
            functionName: "test_3",
            maxSize: 3,
            initAwait: false,
            placementAwait: false
        ) { item in
            await order.add(item)
        }

        await queue.add(1)
        await queue.add(2)
        await queue.add(3)
        await queue.add(4)

        await waitShort(0.3)

        let values = await order.values()
        XCTAssertEqual(values, [4, 3, 2])
    }

    /// test_4: RemoveAll clears pending items
    func test_4_removeAll_clearsPending() async {
        let processed = Counter()

        let queue = LIFOQueue<Int>(
            functionName: "test_4",
            maxSize: 10,
            initAwait: false,
            placementAwait: false
        ) { _ in
            await self.waitShort(0.2)

            if Task.isCancelled {
                return
            }

            await processed.increment()
        }

        await queue.add(1)
        await queue.cancelWorker()
        await queue.removeAll()

        let count = await queue.count()
        XCTAssertEqual(count, 0)

        await waitShort(0.3)

        let value = await processed.value()
        XCTAssertEqual(value, 0)
    }

    /// test_5: Count returns current pending queue size
    func test_5_count_returnsCorrectSize() async {
        let gate = AsyncGate()

        let queue = LIFOQueue<Int>(
            functionName: "test_5",
            maxSize: 10,
            initAwait: false,
            placementAwait: false
        ) { _ in
            await gate.wait()
        }

        let initialCount = await queue.count()
        XCTAssertEqual(initialCount, 0)

        await queue.add(1)
        await queue.add(2)
        await queue.add(3)

        await waitShort(0.05)

        let countWhileFirstItemProcessing = await queue.count()
        XCTAssertEqual(countWhileFirstItemProcessing, 2)

        await gate.open()
        await waitShort(0.2)

        let finalCount = await queue.count()
        XCTAssertEqual(finalCount, 0)
    }

    /// test_6: Error in processing does not stop queue
    func test_6_errorDoesNotStopQueue() async {
        let order = OrderedInts()

        let queue = LIFOQueue<Int>(
            functionName: "test_6",
            maxSize: 10,
            initAwait: false,
            placementAwait: false
        ) { item in
            if item == 2 {
                throw TestError.fail
            }

            await order.add(item)
        }

        await queue.add(1)
        await queue.add(2)
        await queue.add(3)

        await waitShort(0.3)

        let values = await order.values()
        XCTAssertEqual(values, [3, 1])
    }

    /// test_7: Worker processes new items added during processing
    func test_7_workerProcessesNewItemDuringProcessing() async {
        let order = OrderedInts()

        let queue = LIFOQueue<Int>(
            functionName: "test_7",
            maxSize: 10,
            initAwait: false,
            placementAwait: false
        ) { item in
            await self.waitShort(0.1)
            await order.add(item)
        }

        await queue.add(1)
        await waitShort(0.02)
        await queue.add(2)

        await waitShort(0.5)

        let values = await order.values()
        XCTAssertEqual(values, [1, 2])
    }

    /// test_8: CancelWorker cancels current worker
    func test_8_cancelWorker_cancelsCurrentWorker() async {
        let processed = Counter()

        let queue = LIFOQueue<Int>(
            functionName: "test_8",
            maxSize: 10,
            initAwait: false,
            placementAwait: false
        ) { _ in
            await self.waitShort(0.2)

            if Task.isCancelled {
                return
            }

            await processed.increment()
        }

        await queue.add(1)
        await waitShort(0.02)
        await queue.cancelWorker()

        await waitShort(0.3)

        let value = await processed.value()
        XCTAssertEqual(value, 0)

        let isRunning = await queue.isWorkerRunning()
        XCTAssertFalse(isRunning)
    }

    /// test_9: IsWorkerRunning returns correct state while processing
    func test_9_isWorkerRunning_correctState() async {
        let gate = AsyncGate()

        let queue = LIFOQueue<Int>(
            functionName: "test_9",
            maxSize: 10,
            initAwait: false,
            placementAwait: false
        ) { _ in
            await gate.wait()
        }

        let beforeAdd = await queue.isWorkerRunning()
        XCTAssertFalse(beforeAdd)

        await queue.add(1)
        await waitShort(0.05)

        let whileProcessing = await queue.isWorkerRunning()
        XCTAssertTrue(whileProcessing)

        await gate.open()
        await waitShort(0.2)

        let afterProcessing = await queue.isWorkerRunning()
        XCTAssertFalse(afterProcessing)
    }

    /// test_10: Single item processes correctly
    func test_10_singleItem_processesCorrectly() async {
        let processed = Flag()

        let queue = LIFOQueue<Int>(
            functionName: "test_10",
            maxSize: 10,
            initAwait: false,
            placementAwait: false
        ) { _ in
            await processed.setTrue()
        }

        await queue.add(42)
        await waitShort(0.2)

        let value = await processed.value()
        XCTAssertTrue(value)
    }
}

/// Test error type.
private enum TestError: Error {
    case fail
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

private actor Counter {
    private var storage = 0

    func increment() {
        storage += 1
    }

    func value() -> Int {
        storage
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

private actor AsyncGate {
    private var isOpen = false

    func open() {
        isOpen = true
    }

    func wait() async {
        while !isOpen && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
