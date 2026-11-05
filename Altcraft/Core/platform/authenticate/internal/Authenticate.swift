//
//  Authenticate.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Handles SDK authentication flow.
///
/// Authenticates the Altcraft user, switches the session
/// from anonymous to identified, updates stored auth state,
/// and processes pending auth requests through a serial queue.
actor Authenticate {

    static let shared = Authenticate()
    let backgroundTask = AccessToBackground.shared

    /// Serial queue for starting authentication processing.
    ///
    /// Uses epoch invalidation to drop stale processing jobs when a new
    /// authentication flow is triggered.
    static let startQueue = SerialCommandQueue(
        label: Constants.Queues.AuthRequestStartQueue,
        usesEpoch: true
    )

    /// Builds a formatted function tag for logs.
    ///
    /// - Parameter name: The source function name.
    /// - Returns: Function name decorated with the authenticate scope.
    private func getFunc(_ name: String) -> String {
        "\(name) :: Authenticate"
    }

    /// Stores or updates an auth request and starts queued processing.
    func authenticate() async {
        await backgroundTask.accessToBackground()
        let initGate = await InitBarrier.shared.current()

        await withInitReady(function: #function, gate: initGate) {
            let context = CoreDataManager.shared.getContext()
            let env = Environment.create()

            do {
                try env.checkCoreDataError()

                let userTag = try await env.userTag()
                let auth = try await env.internalAuth()

                if userTag == auth.currentUserTag {
                    return
                }

                if await getAuthRequestSnapshot(context: context)?.userTag != userTag {
                    await addAuthRequestEntity(userTag: userTag)
                }

                RetryCounters.shared.reset(RetryKey.auth)
                await self.enqueueStart()
            } catch {
                CoreLog.error(#function, error: error)
            }
        }
    }

    /// Enqueues auth processing into the serial queue.
    ///
    /// - Parameter enableRetry: If `true`, schedules retry on recoverable failure.
    func enqueueStart(enableRetry: Bool = true) async {
        let function = getFunc(#function)

        Authenticate.startQueue.submit {
            do {
                await NetworkMonitor.shared.waitConnected()

                let env = Environment.create()
                let userTag = try await env.userTag()

                let result = await self.processRequests(userTag: userTag)

                if !result && enableRetry {
                    authRetry()
                }
            } catch {
                CoreLog.retry(function, error: error)

                if enableRetry {
                    authRetry()
                }
            }
        }
    }

    /// Processes the current pending auth request.
    ///
    /// Deletes stale requests when the stored user tag does not match
    /// the current SDK user tag.
    ///
    /// - Parameter userTag: Current SDK user tag.
    /// - Returns: `true` if processing is completed, otherwise `false`.
    fileprivate func processRequests(userTag: String) async -> Bool {
        let context = CoreDataManager.shared.getContext()

        guard let request = await getAuthRequestSnapshot(context: context) else {
            return true
        }

        if request.userTag != userTag {
            deleteAllAuthRequests(context: context)
            return true
        }

        return !(await isRetry(
            context: context,
            request: request.objectID,
            userTag: request.userTag ?? ""
        ))
    }

    /// Processes a single auth request and checks whether retry is needed.
    ///
    /// On success, updates current ACID, current user tag, test mode flag,
    /// and anonymous ACID if the anonymous profile was replaced by the server.
    ///
    /// - Parameters:
    ///   - context: Managed object context used for the operation.
    ///   - request: Auth request object identifier.
    ///   - userTag: User tag from the stored auth request.
    /// - Returns: `true` if retry should be scheduled, otherwise `false`.
    fileprivate func isRetry(
        context: NSManagedObjectContext,
        request: NSManagedObjectID,
        userTag: String
    ) async -> Bool {
        let response = await self.request(
            context: context,
            request: request
        )

        switch response.event {
        case is RetryEvent:
            return !(await retryLimit(
                context: context,
                objectID: request
            ))

        default:
            _ = await deleteEntity(
                context: context,
                objectID: request
            )
        }

        guard let acid = response.acid else {
            return false
        }

        await updateCurrentAcid(context: context, acid: acid)
        await updateCurrentTag(context: context, tag: userTag)
        await updateIsTest(context: context, isTest: response.isTest)

        do {
            let internalAuth = try await Environment.create().internalAuth()

            if internalAuth.anonimAcid == acid {
                await updateAnonAcid(
                    context: context,
                    acid: getNano12()
                )
            }
        } catch {
            CoreLog.error(getFunc(#function), error: error)
        }

        return false
    }

    /// Builds and sends the auth request.
    ///
    /// - Parameters:
    ///   - context: Managed object context used to read the pending request.
    ///   - objectID: Auth request object identifier.
    /// - Returns: Parsed auth response data with SDK event result.
    fileprivate func request(
        context: NSManagedObjectContext,
        request objectID: NSManagedObjectID
    ) async -> AuthResponse {
        let function = getFunc(#function)

        guard let requestData = await AuthenticateModel.of(
            context: context,
            objectID: objectID
        ) else {
            return AuthResponse(
                acid: nil,
                isTest: false,
                event: CoreLog.retry(
                    function,
                    error: CoreEvents.failedCreateRequest
                )
            )
        }

        guard let request = authRequest(data: requestData) else {
            return AuthResponse(
                acid: nil,
                isTest: false,
                event: CoreLog.retry(
                    function,
                    error: CoreEvents.failedCreateRequest
                )
            )
        }

        let result = await RequestManager.shared.sendRequest(
            request: request,
            requestData: requestData
        )

        return AuthResponse(
            acid: result.response?.acid,
            isTest: result.response?.isTest ?? false,
            event: result.event
        )
    }

    /// Initializes internal authentication state if it does not exist yet.
    ///
    /// Creates an anonymous auth record with generated ACID and device ID.
    func setAuth() async {
        let context = CoreDataManager.shared.getContext()

        guard !(await authenticationEntityExists(context: context)) else {
            return
        }

        let acid = getNano12()

        await addAuthenticationEntity(
            currentAcid: acid,
            anonimAcid: acid,
            deviceId: generateUUID(),
            currentUserTag: nil,
            startAnonSession: getCurrentTimeMillis()
        )
    }

    /// Restores anonymous auth state.
    ///
    /// Keeps stored anonymous ACID and device ID,
    /// clears current user tag, and starts a new anonymous session.
    func logOut() async {
        let function = getFunc(#function)
        let context = CoreDataManager.shared.getContext()

        guard await authenticationEntityExists(context: context) else {
            return
        }

        CoreLog.event(#function, event: CoreEvents.userLogOut)
        await deleteAcidSensitiveRequests()

        do {
            let internalAuth = try await Environment
                .create()
                .internalAuth()

            await addAuthenticationEntity(
                currentAcid: internalAuth.anonimAcid,
                anonimAcid: internalAuth.anonimAcid,
                deviceId: internalAuth.deviceId,
                currentUserTag: nil,
                startAnonSession: getCurrentTimeMillis()
            )
        } catch {
            CoreLog.error(function, error: error)
        }
    }

    /// Checks whether current SDK user is authenticated.
    ///
    /// Creates the SDK environment internally and delegates to
    /// ``isAuthenticated(env:)``.
    ///
    /// - Returns: `true` if current user tag matches stored auth state.
    func isAuthenticated() async -> Bool {
        await isAuthenticated(env: Environment.create())
    }

    /// Checks whether current SDK user is authenticated.
    ///
    /// - Parameter env: SDK environment providing internal auth data and current user tag.
    /// - Returns: `true` if current user tag matches stored auth state.
    func isAuthenticated(env: Environment) async -> Bool {
        do {
            let userTag = try await env.userTag()
            let internalAuth = try await env.internalAuth()

            guard let currentUserTag = internalAuth.currentUserTag else {
                return false
            }

            return currentUserTag == userTag
        } catch {
            return false
        }
    }
}

/// Auth request result used inside authentication flow.
private struct AuthResponse {
    let acid: String?
    let isTest: Bool
    let event: Event
}

/// Deletes requests that must be cleared
/// after authentication state changes.
///
/// This cleanup removes requests bound to the previous ACID:
/// - pending authentication requests (core module);
/// - pending module requests bound to the previous ACID
///   (each registered module handles its own cleanup).
func deleteAcidSensitiveRequests() async {
    let context = CoreDataManager.shared.getContext()

    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            deleteAllAuthRequests(context: context)
        }

        group.addTask {
            await ModuleRegistry.shared.notifyAuthStateChanged()
        }
    }
}
