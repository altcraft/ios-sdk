//
//  SDKStateCoordinator.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

final class SDKStateCoordinator: @unchecked Sendable {

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

    /// Sets the App Group identifier and applies it immediately in a strictly ordered way.
    ///
    /// - Parameter groupName: App Group identifier used for the shared container.
    func setAppGroup(_ groupName: String?) {
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
    func prepareAppGroupIdentifier() {
        stateQueue.sync {
            guard !isAppGroupPrepared else {
                return
            }
            applyAppGroupLocked(
                currentAppGroup
            )
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
    /// - initializes Core Data with the specified shared container
    func applyAppGroupLocked(_ groupName: String?) {
        _ = CoreDataManager(appGroup: groupName)
        StoredVariablesManager.shared.setGroupsName(
            value: groupName
        )
        isAppGroupPrepared = true
    }
}
