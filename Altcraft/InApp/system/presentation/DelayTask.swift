//
//  DelayTask.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Utility actor for scheduling delayed in-app campaign presentations.
///
/// Handles:
/// - calculating trigger delays
/// - managing delayed task execution
/// - resetting trigger delays after presentation
///
/// Every scheduled presentation is registered in the pending-task registry,
/// so ``cancelAll()`` can stop presentations that were scheduled before the
/// SDK state was cleared (e.g. by `AltcraftSDK.clear()`).
@available(iOSApplicationExtension, unavailable)
actor DelayTask {

    /// Shared instance.
    static let shared = DelayTask()

    /// Pending delayed presentations keyed by unique identifiers.
    ///
    /// Each entry owns the detached task running the delayed flow. The
    /// registry is the only handle that can cancel a scheduled presentation;
    /// an entry is removed when its task finishes or is cancelled.
    private var pendingTasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    /// Returns the configured delay for the trigger that started the in-app campaign.
    ///
    /// The trigger is matched by both name and type.
    ///
    /// - Parameter inApp: In-app campaign.
    /// - Returns: Delay in seconds for the matched trigger, or `0` if not set.
    static func getTriggerDelay(
        _ inApp: InAppModel.InApp
    ) -> Int {
        inApp.options.triggerEvents.first {
            $0.name == inApp.actionTriggerName &&
            $0.type.caseInsensitiveCompare(
                inApp.actionTriggerType.rawValue
            ) == .orderedSame
        }?.delay ?? 0
    }

    /// Schedules delayed presentation of an in-app campaign.
    ///
    /// Before presentation, the matched trigger delay is reset to `0`
    /// in the copied campaign instance to avoid repeated delayed processing.
    ///
    /// Display counters are not touched here: they are incremented
    /// at shown-time by `InAppVariables.updateInAppVariables`, so the
    /// delayed revalidation sees only committed displays.
    ///
    /// The scheduled task is registered in the pending registry, so a later
    /// ``cancelAll()`` (e.g. SDK clear) can stop it before presentation.
    ///
    /// - Parameters:
    ///   - inApp: In-app campaign.
    ///   - trigger: Trigger that started the in-app campaign.
    ///   - delay: Delay before presentation in seconds.
    func delayTask(
        inApp: InAppModel.InApp,
        trigger: InAppModel.InAppTrigger,
        delay: Int
    ) {
        let id = UUID()

        let task = Task.detached(priority: .utility) { [weak self] in
            _ = await self?.runPresentation(
                id: id,
                inApp: inApp,
                trigger: trigger,
                delay: delay
            )
        }

        pendingTasks[id] = task
    }

    /// Cancels every pending delayed presentation.
    ///
    /// Scheduled presentations stopped this way never run, even if their
    /// delay has already elapsed.
    func cancelAll() {
        pendingTasks.values.forEach { $0.cancel() }
        pendingTasks.removeAll()
    }

    /// Runs the delayed presentation flow for a scheduled task.
    ///
    /// When the task is cancelled during the sleep (e.g. SDK state was
    /// cleared), the presentation never runs.
    private func runPresentation(
        id: UUID,
        inApp: InAppModel.InApp,
        trigger: InAppModel.InAppTrigger,
        delay: Int
    ) async {
        do {
            try await Task.sleep(
                nanoseconds: UInt64(max(0, delay)) * 1_000_000_000
            )
        } catch {
            // The task was cancelled (e.g. SDK state was cleared): the
            // delayed presentation must not run.
            pendingTasks.removeValue(forKey: id)
            return
        }

        pendingTasks.removeValue(forKey: id)

        // Cancellation can land between the sleep deadline firing and this
        // section running on the actor: the sleep then returns without
        // throwing, so the flag is checked explicitly to keep a presentation
        // from running after the SDK state was cleared.
        guard !Task.isCancelled else {
            return
        }

        let resetDelayInApp = Self.resetTriggerDelay(
            inApp,
            trigger: trigger
        )

        await Presenter.present(
            resetDelayInApp,
            delayTask: true,
            trigger: trigger
        )
    }

    /// Creates a copy of in-app with delay reset to 0 for the matched trigger.
    ///
    /// The trigger is matched by both name and type.
    ///
    /// - Parameters:
    ///   - inApp: In-app campaign.
    ///   - trigger: Trigger that started the in-app campaign.
    /// - Returns: Copy with delay reset for the matched trigger.
    static func resetTriggerDelay(
        _ inApp: InAppModel.InApp,
        trigger: InAppModel.InAppTrigger
    ) -> InAppModel.InApp {
        let triggerEvents = inApp.options.triggerEvents.map { event in
            let isMatchedTrigger =
                event.name == trigger.name &&
                event.type.caseInsensitiveCompare(
                    trigger.type.rawValue
                ) == .orderedSame

            guard isMatchedTrigger else {
                return event
            }

            return InAppModel.TriggerEvent(
                type: event.type,
                name: event.name,
                delay: 0
            )
        }

        let options = InAppModel.PlacementOptions(
            endTime: inApp.options.endTime,
            policy: inApp.options.policy,
            isAnonim: inApp.options.isAnonim,
            placements: inApp.options.placements,
            appVersions: inApp.options.appVersions,
            appVersionConditionRaw: inApp.options.appVersionConditionRaw,
            priority: inApp.options.priority,
            triggerEvents: triggerEvents,
            impressionsLimit: inApp.options.impressionsLimit,
            availability: inApp.options.availability
        )

        return InAppModel.InApp(
            uid: inApp.uid,
            companyId: inApp.companyId,
            smid: inApp.smid,
            type: inApp.type,
            contentUrl: inApp.contentUrl,
            checksum: inApp.checksum,
            options: options,
            deadline: inApp.deadline,
            isTest: inApp.isTest,
            lastCompanyUpdate: inApp.lastCompanyUpdate,
            actionTriggerName: trigger.name,
            actionTriggerType: trigger.type
        )
    }
}
