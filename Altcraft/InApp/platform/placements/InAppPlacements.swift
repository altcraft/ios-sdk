//
//  InAppPlacements.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Contains functions for requesting and processing in-app placements.
@available(iOSApplicationExtension, unavailable)
internal actor InAppPlacementsProcess {

    /// Shared singleton instance.
    static let shared = InAppPlacementsProcess()

    /// Processes SDK commands sequentially within this queue.
    private let queue = SerialCommandQueue(
        label: InAppConstants.Queues.inAppPlacementsQueue,
        usesEpoch: false
    )

    /// Indicates whether in-app placements are ready for trigger processing.
    private var isPlacementsReady = false

    /// Continuations waiting until placements become ready.
    private var placementsWaiters: [CheckedContinuation<Void, Never>] = []

    /// Builds a formatted function tag for logs.
    ///
    /// - Parameter name: Source function name.
    /// - Returns: Function name decorated with the in-app placements scope.
    private func getFunc(_ name: String) -> String {
        "\(name) :: InAppPlacementsProcess"
    }

    /// Suspends execution until in-app placements are ready.
    func waitUntilReady() async {
        if isPlacementsReady {
            return
        }

        await withCheckedContinuation { continuation in
            placementsWaiters.append(continuation)
        }
    }

    /// Loads in-app placements.
    ///
    /// Creates one request identifier for the complete placements operation.
    /// The same identifier is used by the initial request and every retry.
    ///
    /// Automatic requests are skipped when `inAppAutoRequest` is disabled
    /// in the SDK configuration. Requests explicitly initiated by the user
    /// are always allowed.
    ///
    /// Waits for SDK initialization to complete before reading configuration
    /// and auth data (Android parity, `submitSdkCommand` with
    /// `initAwait = true`), so a request submitted before `initialization`
    /// is processed once the configuration is installed.
    ///
    /// - Parameters:
    ///   - userReq: If `true`, request is forced by public API and ignores
    ///     automatic request configuration and request timeout.
    ///   - enableRetry: If `true`, schedules retry when processing fails.
    func requestPlacements(
        userReq: Bool = false,
        enableRetry: Bool = true
    ) async {
        let function = getFunc(#function)

        queue.submit {
            let initGate = await InitBarrier.shared.current()

            await withInitReady(function: function, gate: initGate) {
                do {
                    let env = InAppEnvironment.fresh()
                    try env.checkCoreDataError()

                    let config = await env.config()

                    guard config.inAppAutoRequest || userReq else {
                        await self.placementsReady()
                        return
                    }

                    let auth = try await env.internalAuth()
                    let context = inAppDatabase.getContext()
                    let state = await InAppsDAO.getInAppsState(context: context)

                    if state?.acid != auth.currentAcid ||
                        state?.deviceId != auth.deviceId {

                        await InAppDAO.deleteAllInAppEntities()
                        await InAppsDAO.clearInAppsData()

                    } else if !userReq
                                && !auth.isTest
                                && !InAppPlacementCountManager.isMaxPlacementsChanged()
                                && Self.isRequestTooEarly(
                                    state,
                                    intervalMs: config.placementsRequestInterval
                                ) {
                        await self.placementsReady()
                        return
                    }

                    InAppPlacementCountManager.resetMaxPlacementsChanged()

                    RetryCounters.shared.reset(
                        InAppConstants.RetryKey.inAppPlacements
                    )

                    await self.enqueueStart(
                        enableRetry: enableRetry,
                        requestId: UUID().uuidString
                    )
                } catch {
                    InAppLog.error(function, error: error)
                    await self.placementsReady()
                }
            }
        }
    }

    /// Enqueues in-app placements processing into the serial command queue.
    ///
    /// When called without a request identifier, creates a new identifier for
    /// a new operation. Retry logic always supplies the existing identifier.
    ///
    /// - Parameters:
    ///   - enableRetry: If `true`, schedules retry when processing fails.
    ///   - requestId: Identifier shared by all attempts of the current operation.
    func enqueueStart(
        enableRetry: Bool = true,
        requestId: String? = nil
    ) async {
        let currentRequestId = requestId ?? UUID().uuidString

        queue.submit {
            await NetworkMonitor.shared.waitConnected()

            let result = await self.processPlacements(
                requestId: currentRequestId
            )

            if !result && enableRetry {
                inAppPlacementsRetry(
                    requestId: currentRequestId
                )
            }
        }
    }

    /// Processes pending in-app placements request.
    ///
    /// The method:
    /// - loads or creates current in-app synchronization state;
    /// - requests actual placements from backend;
    /// - discards the response when the current identity does not match the
    ///   identity the request was made with;
    /// - stores updated state;
    /// - saves regular in-app campaigns;
    /// - creates missing personal policy rows for received in-app campaigns;
    /// - sends delivery events for campaigns whose personal policy has not been reported;
    /// - marks reported campaigns as delivered locally;
    /// - removes personal policies for current ACID whose SMID is no longer available;
    /// - sends delivery events for test campaigns and presents them in test mode.
    ///
    /// A retryable failure keeps the placements readiness gate closed (Android
    /// parity): parked trigger workers wait for a retry pass to succeed. Hard
    /// errors that leave the processing flow still mark placements as ready,
    /// so parked trigger workers are released and never wait indefinitely; the
    /// same release happens when the local retry limit is reached without
    /// success (``retryBudgetExhausted()``).
    ///
    /// - Parameter requestId: Identifier shared by all attempts of the operation.
    /// - Returns: `true` if processing completed, otherwise `false`.
    fileprivate func processPlacements(
        requestId: String
    ) async -> Bool {
        let context = inAppDatabase.getContext()
        let env = InAppEnvironment.fresh()

        do {
            let config = await env.config()
            let auth = try await env.internalAuth()

            let storedState = await InAppsDAO.getInAppsState(
                context: context
            )

            let state = InAppModel.InAppsState(
                acid: storedState?.acid ?? auth.currentAcid,
                deviceId: storedState?.deviceId ?? auth.deviceId,
                lastRequestTime: storedState?.lastRequestTime ?? 0,
                lastPublish: storedState?.lastPublish ?? 0,
                placementRulesChecksum: storedState?.placementRulesChecksum ?? ""
            )

            let response = await request(
                state: state,
                requestId: requestId
            )

            switch response.event {
            case is RetryEvent:
                // The placements readiness gate stays closed on a retryable
                // failure (Android parity, `PlacementsProcess.logic`):
                // parked trigger workers wait until a retry pass succeeds.
                // When the retry budget is exhausted without success,
                // ``retryBudgetExhausted()`` releases them.
                return false

            default:
                break
            }

            // Discarding the response when the current identity does not
            // match the identity the request was made with: saving it would
            // resurrect data of the previous user (Android parity,
            // `PlacementsProcess.logic`).
            let currentAuth = try await env.internalAuth()
            if state.acid != currentAuth.currentAcid ||
                state.deviceId != currentAuth.deviceId {
                return false
            }

            let now = getCurrentTimeMillis()

            guard let inAppsResponse = response.response else {
                switch await InAppsDAO.setInAppsEntity(
                    acid: state.acid,
                    lastRequestTime: now,
                    deviceId: state.deviceId,
                    lastPublish: state.lastPublish,
                    placementRulesChecksum: state.placementRulesChecksum
                ) {
                case .success:
                    await placementsReady()
                    return true

                case .failure:
                    await placementsReady()
                    return false
                }
            }

            let newState = inAppsResponse.toState(
                acid: state.acid,
                deviceId: state.deviceId,
                lastRequestTime: now
            )

            switch await InAppsDAO.setInAppsEntity(
                acid: newState.acid,
                lastRequestTime: newState.lastRequestTime,
                deviceId: newState.deviceId,
                lastPublish: newState.lastPublish,
                placementRulesChecksum: newState.placementRulesChecksum
            ) {
            case .success:
                break

            case .failure:
                await placementsReady()
                return false
            }

            let inApps = InAppPlacementCountManager.trimToMax(
                inAppsResponse.inApps,
                max: config.maxPlacements
            )

            await InAppDAO.saveInAppEntities(
                inApps
            )

            await InAppDAO.savePersonalPolicyEntities(
                acid: state.acid,
                items: inApps
            )

            let unreportedInApps = await InAppDAO.getUnreportedInApps()

            for inApp in unreportedInApps {
                await InAppEventProcess.shared.createInAppEvent(
                    smid: inApp.smid,
                    type: .delivery
                )
            }

            await InAppDAO.deletePersonalPoliciesNotIn(
                acid: auth.currentAcid,
                smidList: inApps.map {
                    $0.smid
                }
            )

            for inApp in inAppsResponse.testInApps {
                await InAppEventProcess.shared.createInAppEvent(
                    smid: inApp.smid,
                    type: .delivery
                )

                if auth.isTest {
                    await InAppPresenter.present(inApp)
                }
            }

            await placementsReady()
            return true

        } catch {
            InAppLog.error(
                getFunc(#function),
                error: error
            )
            await placementsReady()
            return false
        }
    }

    /// Builds and sends an in-app placements request.
    ///
    /// - Parameters:
    ///   - state: Current persisted in-app synchronization state.
    ///   - requestId: Identifier shared by all attempts of the operation.
    /// - Returns: Parsed response with SDK event result.
    fileprivate func request(
        state: InAppModel.InAppsState,
        requestId: String
    ) async -> InAppPlacementsResponse {
        let function = getFunc(#function)

        guard let requestData = await getInAppPlacementsRequestData(
            state: state,
            requestId: requestId
        ) else {
            return InAppPlacementsResponse(
                response: nil,
                event: InAppLog.retry(
                    function,
                    error: CoreEvents.failedCreateRequest
                )
            )
        }

        guard let request = await inAppPlacementsRequest(
            data: requestData
        ) else {
            return InAppPlacementsResponse(
                response: nil,
                event: InAppLog.retry(
                    function,
                    error: CoreEvents.failedCreateRequest
                )
            )
        }

        let result = await RequestManager.shared.sendRequest(
            request: request,
            requestData: requestData
        )

        return InAppPlacementsResponse(
            response: result.response,
            event: result.event
        )
    }

    /// Returns `true` when requesting placements is still too early.
    ///
    /// - Parameters:
    ///   - state: Current in-app placements state.
    ///   - intervalMs: Configured interval between automatic requests, in ms.
    /// - Returns: `true` if the last request happened less than `intervalMs`
    ///   ago.
    private nonisolated static func isRequestTooEarly(
        _ state: InAppsStateSnapshot?,
        intervalMs: Int64
    ) -> Bool {
        guard let state else {
            return false
        }

        guard intervalMs > 0 else {
            return false
        }

        return getCurrentTimeMillis() - state.lastRequestTime < intervalMs
    }

    /// Marks in-app placements as ready and resumes all waiting continuations.
    private func placementsReady() async {
        guard !isPlacementsReady else {
            return
        }

        isPlacementsReady = true

        let waiters = placementsWaiters
        placementsWaiters.removeAll()

        for waiter in waiters {
            waiter.resume()
        }
    }

    /// Marks in-app placements as ready when the retry budget is exhausted.
    ///
    /// Called by ``inAppPlacementsRetry(requestId:)`` when no further retry
    /// is scheduled: parked trigger workers are released instead of waiting
    /// for a placements pass that will never run. iOS has no periodic worker
    /// guarantee comparable to Android WorkManager, so without this release
    /// the parked triggers would never resume.
    func retryBudgetExhausted() async {
        await placementsReady()
    }

    /// Resets placements readiness, e.g. when the SDK clears in-app data or
    /// the SDK rToken changes.
    ///
    /// Clears the readiness flag and re-arms the gate. Parked trigger workers
    /// are NOT released: they stay parked and are resumed only when the next
    /// placements request completes the re-armed gate, so queued triggers are
    /// processed exclusively with fresh placement data (Android parity,
    /// `LIFOQueue` re-park loop and `PlacementsProcess.reset`).
    ///
    /// The follow-up request is guaranteed by the rToken-change flow, which
    /// issues it immediately; hard failures release the parked workers through
    /// the error paths and ``retryBudgetExhausted()``.
    func reset() async {
        isPlacementsReady = false
    }
}

/// In-app placements request result used inside placements flow.
private struct InAppPlacementsResponse {

    /// Parsed response body.
    let response: InAppPlacesResponse?

    /// SDK event result.
    let event: Event
}

// MARK: - Unit Test Hooks

extension InAppPlacementsProcess {

    /// Test hook for in-app placements processing.
    ///
    /// - Parameter requestId: Identifier used by the tested processing flow.
    /// - Returns: `true` if processing completed, otherwise `false`.
    internal func test_inApp_placements_processPlacements(
        requestId: String = UUID().uuidString
    ) async -> Bool {
        await processPlacements(
            requestId: requestId
        )
    }

    /// Test hook for an in-app placements request event.
    ///
    /// - Parameters:
    ///   - state: Current persisted in-app synchronization state.
    ///   - requestId: Identifier used by the tested request.
    /// - Returns: Resulting SDK event.
    internal func test_inApp_placements_requestEvent(
        state: InAppModel.InAppsState,
        requestId: String = UUID().uuidString
    ) async -> Event {
        await request(
            state: state,
            requestId: requestId
        ).event
    }
}
