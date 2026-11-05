//
//  SDKStateCoordinator.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Coordinates SDK-wide initialization gates and environment state.
@_spi(_Altcraft) public final class SDKStateCoordinator: @unchecked Sendable {
    /// Shared instance.
    public static let shared = SDKStateCoordinator()

    /// Serial queue for SDK state mutations that must happen in strict order.
    ///
    /// This queue guarantees ordered execution between:
    /// - setAppGroup(groupName:)
    /// - preparation steps performed before initialization(...)
    ///
    /// Important:
    /// If setAppGroup(...) is called before initialization(...),
    /// its internal work is guaranteed to finish first.
    private let stateQueue = DispatchQueue(
        label: Constants.Queues.sdkStateQueue
    )

    /// Last configured App Group value.
    ///
    /// Access only on stateQueue.
    private var currentAppGroup: String?

    /// Whether the App Group setup has already been applied for currentAppGroup.
    ///
    /// Access only on stateQueue.
    private var isAppGroupPrepared = false

    /// Private to guarantee that `shared` is the only instance.
    private init() {}

    /// Sets the App Group identifier and applies it immediately in a strictly ordered way.
    ///
    /// - Parameter groupName: App Group identifier used for the shared container.
    public func setAppGroup(_ groupName: String?) {
        stateQueue.sync {
            currentAppGroup = groupName
            applyAppGroupLocked(groupName)
        }
    }

    /// Ensures that the current App Group configuration has been applied
    /// before SDK initialization starts.
    ///
    /// This method is safe to call many times.
    /// If the current App Group has already been prepared, it does nothing.
    /// If no App Group has been installed yet, it does nothing as well:
    /// `nil` is never applied here and the prepared flag stays unset.
    public func prepareAppGroupIdentifier() {
        stateQueue.sync {
            guard !isAppGroupPrepared else {
                return
            }
            guard let groupName = currentAppGroup else {
                return
            }
            applyAppGroupLocked(groupName)
        }
    }

    /// Resets in-memory coordinator state after the SDK cache has been cleared.
    ///
    /// `clearAllSDKUserDefaults()` also removes the App Group name from
    /// UserDefaults; this method synchronizes the coordinator's memory with
    /// that wiped state, so a later `prepareAppGroupIdentifier()` does not
    /// treat stale configuration as prepared.
    ///
    /// Must be called after the stored values have been cleared.
    func resetState() {
        stateQueue.sync {
            currentAppGroup = nil
            isAppGroupPrepared = false
        }
    }
}

private extension SDKStateCoordinator {

    /// Applies App Group configuration.
    ///
    /// Must be called only on stateQueue.
    ///
    /// Side effects:
    /// - stores the App Group identifier
    ///
    /// The per-module `CoreDataManager` stacks are lazily initialized, so they
    /// pick up the stored App Group identifier on first access.
    func applyAppGroupLocked(_ groupName: String?) {
        StoredVariablesManager.shared.setGroupsName(
            value: groupName
        )
        isAppGroupPrepared = true
    }
}
