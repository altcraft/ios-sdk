//
//  InAppVariables.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Thread-safe session-scoped state used for in-app display conditions.
@available(iOSApplicationExtension, unavailable)
final class InAppVariables: @unchecked Sendable {

    /// Shared singleton instance.
    static let shared = InAppVariables()

    /// Lock protecting all shared state.
    private let lock = NSLock()

    /// Current screen or placement where in-app messages may be shown.
    private var currentScreen: String?

    /// Number of in-app messages opened during the current session.
    private var openBySession: Int = 0

    /// Number of in-app messages opened by default SDK-generated triggers.
    private var triggerBySessionDefault: [String: Int] = [:]

    /// Number of in-app messages opened by custom user-defined triggers.
    private var triggerBySessionCustom: [String: Int] = [:]

    private init() {}

    /// Returns the current placement.
    ///
    /// - Returns: Current screen or `nil` if not set.
    func getCurrentPlacement() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return currentScreen
    }

    /// Updates the current placement.
    ///
    /// If placement changes, emits the default open page in-app trigger.
    ///
    /// - Parameter value: Screen name or placement identifier to set.
    func setCurrentScreen(_ value: String?) {
        lock.lock()
        let shouldTriggerOpenPage = currentScreen != value
        currentScreen = value
        lock.unlock()

        guard shouldTriggerOpenPage else { return }

        InAppProcTrigger.trigger(
            InAppModel.InAppTrigger(
                name: InAppConstants.InAppDefaultTriggerType.openPage,
                type: .default
            )
        )
    }

    /// Returns the number of in-app messages opened in the current session.
    ///
    /// - Returns: Session open count.
    func getOpenBySession() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return openBySession
    }

    /// Increments the number of in-app messages opened in the current session.
    ///
    /// Thread-safe; protected by the internal lock.
    func openBySessionInc() {
        lock.lock()
        openBySession += 1
        lock.unlock()
    }

    /// Updates in-app session state after display.
    ///
    /// Increments session counters for the committed display
    /// (both immediate and delayed), checks open count limits,
    /// and saves the last display time.
    ///
    /// - Parameters:
    ///   - inApp: Displayed in-app campaign.
    ///   - trigger: Trigger that started the in-app campaign.
    func updateInAppVariables(
        inApp: InAppModel.InApp,
        trigger: InAppModel.InAppTrigger
    ) async {
        openBySessionInc()
        triggerBySessionInc(trigger)

        await InAppStoredVariables.shared.setInAppLastOpenTime()
        await Check.PersonalPolicy.checkPersonalPolicy(inApp: inApp)
    }

    /// Returns the number of opens for the specified trigger.
    ///
    /// - Parameters:
    ///   - triggerType: Trigger type used to select the corresponding counter map.
    ///   - triggerName: Trigger name used as the counter key.
    /// - Returns: Number of in-app opens for the specified trigger.
    func getTriggerCount(
        _ triggerType: InAppModel.TriggerType,
        _ triggerName: String
    ) -> Int {
        lock.lock()
        defer { lock.unlock() }

        switch triggerType {
        case .custom:
            return triggerBySessionCustom[triggerName] ?? 0
        case .default:
            return triggerBySessionDefault[triggerName] ?? 0
        }
    }

    /// Increments the open counter for the specified trigger.
    ///
    /// - Parameter trigger: Trigger that started the in-app campaign.
    func triggerBySessionInc(
        _ trigger: InAppModel.InAppTrigger
    ) {
        lock.lock()
        defer { lock.unlock() }

        switch trigger.type {
        case .custom:
            triggerBySessionCustom[trigger.name] =
                (triggerBySessionCustom[trigger.name] ?? 0) + 1

        case .default:
            triggerBySessionDefault[trigger.name] =
                (triggerBySessionDefault[trigger.name] ?? 0) + 1
        }
    }

    /// Increments the open counter for the trigger associated with the given in-app.
    ///
    /// - Parameter inApp: In-app campaign containing trigger type and trigger name.
    func triggerBySessionInc(
        _ inApp: InAppModel.InApp
    ) {
        lock.lock()
        defer { lock.unlock() }

        switch inApp.actionTriggerType {
        case .custom:
            triggerBySessionCustom[inApp.actionTriggerName] =
                (triggerBySessionCustom[inApp.actionTriggerName] ?? 0) + 1

        case .default:
            triggerBySessionDefault[inApp.actionTriggerName] =
                (triggerBySessionDefault[inApp.actionTriggerName] ?? 0) + 1
        }
    }

    /// Clears session-scoped display counters.
    ///
    /// The current screen is preserved: screen state is owned by
    /// the application and survives SDK data clears and rToken changes
    /// (Android parity, `InAppVariables.reset`).
    func reset() {
        lock.lock()
        openBySession = 0
        triggerBySessionDefault.removeAll()
        triggerBySessionCustom.removeAll()
        lock.unlock()
    }
}
