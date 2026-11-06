//
//  InAppProcTrigger.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Processes in-app trigger events.
@available(iOSApplicationExtension, unavailable)
enum InAppProcTrigger {

    private static let queue = LIFOQueue<InAppModel.InAppTrigger>(
        maxSize: 50,
        process: { trigger in await triggerProcessing(trigger) }
    )

    /// Adds an in-app event to the processing queue.
    ///
    /// - Parameter trigger: Trigger event for in-app processing.
    static func trigger(_ trigger: InAppModel.InAppTrigger) {
        Task.detached(priority: .utility) {
            await queue.add(trigger)
        }
    }

    /// Processes an incoming in-app event and presents
    /// the first matching campaign.
    ///
    /// Flow:
    /// - validates that the stored placements identity matches the current
    ///   one, dropping the trigger otherwise;
    /// - retrieves campaigns matching the trigger and placement;
    /// - filters them by availability, version, deadline,
    ///   common policy, and personal policy;
    /// - assigns trigger metadata to the first matching candidate;
    /// - schedules delayed presentation if needed;
    /// - otherwise presents immediately.
    ///
    /// - Parameter trigger: Event that triggered in-app processing.
    private static func triggerProcessing(
        _ trigger: InAppModel.InAppTrigger
    ) async {
        guard await isTriggerIdentityCurrent() else {
            return
        }

        let candidates = await InAppDAO.getTargetInAppList(
            triggerType: trigger.type.rawValue,
            eventName: trigger.name,
            placement: InAppVariables.shared.getCurrentPlacement()
        )

        guard var inApp = await firstAvailableInApp(
            candidates,
            trigger: trigger
        ) else {
            return
        }
    
        inApp.actionTriggerName = trigger.name
        inApp.actionTriggerType = trigger.type

        let delay = DelayTask.getTriggerDelay(inApp)

        if delay > 0 {
            await DelayTask.shared.delayTask(
                inApp: inApp,
                trigger: trigger,
                delay: delay
            )

            return
        }

        await Presenter.present(
            inApp,
            trigger: trigger
        )
    }

    /// Returns whether the stored placements identity matches the current one.
    ///
    /// The stored `InAppsState` is written when placements are saved and is
    /// bound to the identity (acid/deviceId) the campaigns were loaded for.
    /// A trigger worker released by an early placements-gate completion must
    /// not present campaigns loaded for a previous identity: between the gate
    /// release and the rToken-change wipe the database still holds the
    /// previous resource's campaigns. The check mirrors the identity
    /// validation in ``InAppPlacementsProcess/requestPlacements``.
    ///
    /// - Returns: `true` when the stored acid/deviceId match the current
    ///   authentication data; `false` on mismatch, missing state, or an
    ///   authentication error.
    static func isTriggerIdentityCurrent() async -> Bool {
        do {
            let env = InAppEnvironment.fresh()
            let auth = try await env.internalAuth()
            let context = inAppDatabase.getContext()
            let state = await InAppsDAO.getInAppsState(context: context)

            return state?.acid == auth.currentAcid
                && state?.deviceId == auth.deviceId
        } catch {
            return false
        }
    }

    /// Drops queued trigger events and cancels pending delayed presentations.
    ///
    /// Called when the SDK state is cleared: triggers and delayed
    /// presentations captured before the clear must not fire afterwards.
    static func clear() async {
        await queue.removeAll()
        await queue.cancelWorker()
        await DelayTask.shared.cancelAll()
    }

    /// Returns the first candidate that passes all runtime display checks.
    ///
    /// - Parameters:
    ///   - candidates: In-app campaigns matching trigger and placement.
    ///   - trigger: Event that triggered in-app processing.
    /// - Returns: First valid in-app campaign, or `nil`.
    private static func firstAvailableInApp(
        _ candidates: [InAppModel.InApp],
        trigger: InAppModel.InAppTrigger
    ) async -> InAppModel.InApp? {
        for candidate in candidates {
            var inApp = candidate
            inApp.actionTriggerName = trigger.name
            inApp.actionTriggerType = trigger.type

            if await Check.canShow(inApp) {
                return inApp
            }
        }
        return nil
    }
}
