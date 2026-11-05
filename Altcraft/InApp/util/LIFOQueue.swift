//
//  LIFOQueue.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Thread-safe LIFO queue that processes items sequentially in a task worker.
///
/// If `initAwait` is `true`, processing starts only after SDK initialization is ready.
/// If `placementAwait` is `true`, processing starts only after in-app placements are ready.
@available(iOSApplicationExtension, unavailable)
internal actor LIFOQueue<T: Sendable> {

    /// Queue entry containing an item.
    private struct QueueItem: Sendable {
        let item: T
    }

    /// Maximum number of items stored in the queue.
    private let maxSize: Int

    /// Name used for logging.
    private let functionName: String

    /// Indicates whether processing should wait for SDK initialization.
    private let initAwait: Bool

    /// Indicates whether processing should wait for in-app placements readiness.
    private let placementAwait: Bool

    /// Item processing closure.
    private let process: @Sendable (T) async throws -> Void

    /// Internal stack used for LIFO item processing.
    private var stack: [QueueItem] = []

    /// Worker task responsible for sequential queue processing.
    private var workerTask: Task<Void, Never>?

    /// Indicates whether the worker is currently running.
    private var workerRunning = false

    /// Creates a new LIFO queue.
    ///
    /// - Parameters:
    ///   - functionName: Name used for logging.
    ///   - maxSize: Maximum number of queued items.
    ///   - initAwait: Whether processing should wait for SDK initialization.
    ///   - placementAwait: Whether processing should wait for in-app placements readiness.
    ///   - process: Async processing closure for each queued item.
    init(
        functionName: String = "InAppLIFOQueue",
        maxSize: Int = 50,
        initAwait: Bool = true,
        placementAwait: Bool = true,
        process: @escaping @Sendable (T) async throws -> Void
    ) {
        self.functionName = functionName
        self.maxSize = max(1, maxSize)
        self.initAwait = initAwait
        self.placementAwait = placementAwait
        self.process = process
        self.stack.reserveCapacity(self.maxSize)
    }

    /// Adds an item to the queue and starts the worker if needed.
    ///
    /// New items are inserted at the front, so the queue behaves as LIFO.
    ///
    /// - Parameter item: Item to enqueue.
    func add(_ item: T) {
        stack.insert(QueueItem(item: item), at: 0)

        if stack.count > maxSize {
            stack.removeLast()
        }

        if !workerRunning {
            workerRunning = true
            startWorker()
        }
    }

    /// Removes all pending items from the queue.
    ///
    /// Does not cancel the currently processing item. The worker will stop
    /// once it finishes the current item and finds the queue empty.
    func removeAll() {
        stack.removeAll(keepingCapacity: true)
    }

    /// Cancels the current worker task.
    ///
    /// Pending items remain in the queue and are not processed.
    /// A subsequent `add(_:)` call starts a new worker.
    func cancelWorker() {
        workerTask?.cancel()
        workerTask = nil
        workerRunning = false
    }

    /// Returns the current number of items in the queue.
    ///
    /// - Returns: Number of queued items.
    func count() -> Int {
        stack.count
    }

    /// Returns whether the worker task is currently active.
    ///
    /// - Returns: `true` if the worker is processing items.
    func isWorkerRunning() -> Bool {
        workerRunning
    }

    /// Starts the queue worker.
    private func startWorker() {
        workerTask = Task { [weak self] in
            guard let self else {
                return
            }

            let initGate = await InitBarrier.shared.current()

            if await self.shouldAwaitInit() {
                await withInitReady(
                    function: await self.getFunctionName(),
                    gate: initGate
                ) {
                    await self.runWorkerAction()
                }
            } else {
                await self.runWorkerAction()
            }

            await self.finishWorker()
        }
    }

    /// Returns whether this queue should wait for SDK initialization.
    private func shouldAwaitInit() -> Bool {
        initAwait
    }

    /// Returns whether this queue should wait for in-app placements readiness.
    private func shouldAwaitPlacements() -> Bool {
        placementAwait
    }

    /// Returns the function name used for logging.
    private func getFunctionName() -> String {
        functionName
    }

    /// Runs sequential processing of queued items.
    private func runWorkerAction() async {
        if shouldAwaitPlacements() {
            await InAppPlacementsProcess.shared.waitUntilReady()
        }

        while !Task.isCancelled {
            guard let next = popNext() else {
                break
            }

            do {
                try await process(next.item)
            } catch is CancellationError {
                break
            } catch {
                InAppLog.error(functionName, error: error)
            }
        }
    }

    /// Marks worker as stopped and restarts it if new items appeared meanwhile.
    private func finishWorker() {
        workerTask = nil
        workerRunning = false

        if !stack.isEmpty {
            workerRunning = true
            startWorker()
        }
    }

    /// Removes the next item from the front of the stack.
    ///
    /// - Returns: Next queued item, or `nil` if queue is empty.
    private func popNext() -> QueueItem? {
        guard !stack.isEmpty else {
            return nil
        }

        return stack.removeFirst()
    }
}

