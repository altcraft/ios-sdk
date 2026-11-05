//
//  InAppDao.swift
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

/// Data-access operations for in-app data.
enum InAppDAO {

    /// Saves full list of in-app campaigns in local storage.
    ///
    /// Campaign data comes from the `inapps` and `placements` response blocks:
    /// - `inapps[].id` is stored as `companyId`;
    /// - `inapps[].smid` is stored as the in-app message identifier;
    /// - placement options contain display rules, trigger rules, priority,
    ///   application version restrictions, availability, and display limits.
    ///
    /// Existing in-app records are deleted first.
    /// Related placement and trigger event data should be deleted automatically
    /// through Core Data cascade rules if relationships are configured this way.
    ///
    /// Main in-app entities and all nested model values are then inserted again
    /// from the latest backend response through `InAppMapper`.
    ///
    /// If the list is empty, all saved in-app campaigns are deleted.
    ///
    /// Personal policy rows are not affected.
    ///
    /// - Parameter items: Actual in-app campaigns received from backend response.
    static func saveInAppEntities(
        _ items: [InAppModel.InApp]
    ) async {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                try deleteAllObjects(
                    of: InAppEntity.self,
                    in: context
                )

                guard !items.isEmpty else {
                    return
                }

                for item in items {
                    let entity = InAppEntity(context: context)
                    try InAppMapper.apply(item, to: entity)
                }

                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Returns all saved in-app campaigns.
    ///
    /// Sorting:
    /// - `priority` ascending: campaigns with lower priority value are selected first;
    /// - `isAnonim` ascending: non-anonymous campaigns are selected before anonymous campaigns;
    /// - `companyId` descending: campaigns with higher company id are selected first.
    ///
    /// - Returns: Saved in-app campaigns, or an empty array if loading fails.
    static func getInAppEntities() async -> [InAppModel.InApp] {
        do {
            return try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<InAppEntity> = InAppEntity.fetchRequest()
                request.sortDescriptors = [
                    NSSortDescriptor(key: "priority", ascending: true),
                    NSSortDescriptor(key: "isAnonim", ascending: true),
                    NSSortDescriptor(key: "companyId", ascending: false)
                ]

                let entities = try context.fetch(request)

                return try entities.map {
                    try InAppMapper.toInApp(entity: $0)
                }
            }
        } catch {
            InAppLog.error(#function, error: error)
            return []
        }
    }

    /// Returns in-app campaigns matching trigger and placement conditions.
    ///
    /// Trigger conditions are checked against `options.triggerEvents`.
    /// Placement conditions are checked against `options.placements`.
    ///
    /// Placement behavior:
    /// - if `placement` is `nil` or empty, placement filtering is skipped;
    /// - if `placement` is not empty, campaigns without placement restrictions match;
    /// - if `placement` is not empty, campaigns containing the requested placement match.
    ///
    /// - Parameters:
    ///   - triggerType: Trigger event type from `trigger_events[].type`, for example `default` or `custom`.
    ///   - eventName: Trigger event name from `trigger_events[].name`, for example `launch` or a custom event name.
    ///   - placement: Optional placement identifier from `placements[]`, for example `home_screen`.
    /// - Returns: Matching in-app campaigns sorted by `getInAppEntities()`.
    static func getTargetInAppList(
        triggerType: String,
        eventName: String,
        placement: String?
    ) async -> [InAppModel.InApp] {
        let inApps = await getInAppEntities()

        return inApps.filter { inApp in
            matchesTriggerEvent(
                inApp,
                triggerType: triggerType,
                eventName: eventName
            )
            && matchesPlacement(
                inApp,
                placement: placement
            )
        }
    }

    /// Returns one saved in-app campaign by company id.
    ///
    /// `companyId` corresponds to `inapps[].id` and `placements[].id` from backend response.
    /// It identifies the campaign and links raw in-app content with placement settings.
    ///
    /// - Parameter companyId: Campaign identifier from backend response field `id`.
    /// - Returns: Matching in-app campaign, or `nil` if it does not exist or loading fails.
    static func getInAppEntity(
        companyId: Int32
    ) async -> InAppModel.InApp? {
        do {
            return try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<InAppEntity> = InAppEntity.fetchRequest()
                request.fetchLimit = 1
                request.predicate = NSPredicate(
                    format: "companyId == %d",
                    companyId
                )

                guard let entity = try context.fetch(request).first else {
                    return nil
                }

                return try InAppMapper.toInApp(entity: entity)
            }
        } catch {
            InAppLog.error(#function, error: error)
            return nil
        }
    }

    /// Deletes one saved in-app campaign by company id.
    ///
    /// Personal policy rows are not affected because personal counters are stored
    /// independently from campaign data.
    ///
    /// - Parameter companyId: Campaign identifier from backend response field `id`.
    static func deleteInAppEntity(
        companyId: Int32
    ) async {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<InAppEntity> = InAppEntity.fetchRequest()
                request.fetchLimit = 1
                request.predicate = NSPredicate(
                    format: "companyId == %d",
                    companyId
                )

                if let entity = try context.fetch(request).first {
                    context.delete(entity)
                }

                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Deletes all saved in-app campaigns.
    ///
    /// Related in-app campaign data is removed from local storage.
    /// Personal policy rows are not affected because open counters and delivery report
    /// status are stored independently from campaign data.
    ///
    /// Important:
    /// This method intentionally does not use `NSBatchDeleteRequest`.
    /// Some Core Data stores, for example `NSMappedObjectStore`, do not support
    /// batch delete requests and can throw an Objective-C exception instead of a
    /// regular Swift error. Fetching objects and deleting them through the context
    /// keeps the behavior compatible with all supported persistent store types.
    static func deleteAllInAppEntities() async {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                try deleteAllObjects(
                    of: InAppEntity.self,
                    in: context
                )
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Inserts personal policy entity only when it does not already exist.
    ///
    /// Personal policy stores per-user/per-device counters independently from campaign data.
    /// Existing policy state is preserved, including `openCount` and `deliveryReport`.
    ///
    /// This mirrors Android `OnConflictStrategy.IGNORE` behavior for personal policies.
    ///
    /// - Parameters:
    ///   - smid: In-app message identifier from `inapps[].smid`.
    ///   - acid: Current Altcraft identifier used to scope personal policy records.
    ///   - deliveryReport: Initial delivery report status for a newly created policy.
    ///   - openCount: Initial personal open/display count for a newly created policy.
    static func insertPersonalPolicyEntity(
        smid: String,
        acid: String,
        deliveryReport: Bool = false,
        openCount: Int32 = 0
    ) async {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<PersonalPolicyEntity> = PersonalPolicyEntity.fetchRequest()
                request.fetchLimit = 1
                request.predicate = NSPredicate(
                    format: "smid == %@",
                    smid
                )

                if try context.fetch(request).first != nil {
                    return
                }

                let entity = PersonalPolicyEntity(context: context)
                entity.smid = smid
                entity.acid = acid
                entity.deliveryReport = deliveryReport
                entity.openCount = openCount

                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Saves missing personal policy rows for received in-app campaigns.
    ///
    /// Existing rows are not overwritten, so local personal state is preserved:
    /// - open count;
    /// - delivery report status.
    ///
    /// This method must be called right after saving in-app campaigns from placements
    /// response and before reading unreported in-apps.
    ///
    /// - Parameters:
    ///   - acid: Current Altcraft identifier used to scope personal policy records.
    ///   - items: In-app campaigns received from backend.
    static func savePersonalPolicyEntities(
        acid: String,
        items: [InAppModel.InApp]
    ) async {
        guard !items.isEmpty else { return }

        do {
            try await inAppDatabase.performBackgroundTask { context in
                let smids = items.map { $0.smid }

                let request: NSFetchRequest<PersonalPolicyEntity> = PersonalPolicyEntity.fetchRequest()
                request.predicate = NSPredicate(
                    format: "smid IN %@",
                    smids
                )

                let existingPolicies = try context.fetch(request)
                let existingSmids = Set(existingPolicies.compactMap { $0.smid })

                for item in items where !existingSmids.contains(item.smid) {
                    let entity = PersonalPolicyEntity(context: context)
                    entity.smid = item.smid
                    entity.acid = acid
                    entity.deliveryReport = false
                    entity.openCount = 0
                }

                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Returns personal open count for the specified SMID.
    ///
    /// The value is used for personal display policy checks, for example campaign
    /// impression limits and repeated display restrictions.
    ///
    /// - Parameter smid: In-app message identifier from `inapps[].smid`.
    /// - Returns: Saved open count, or `nil` if the policy does not exist or loading fails.
    static func getInAppOpenCount(
        smid: String
    ) async -> Int32? {
        do {
            return try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<PersonalPolicyEntity> = PersonalPolicyEntity.fetchRequest()
                request.fetchLimit = 1
                request.predicate = NSPredicate(
                    format: "smid == %@",
                    smid
                )

                return try context.fetch(request).first?.openCount
            }
        } catch {
            InAppLog.error(#function, error: error)
            return nil
        }
    }

    /// Increments personal open count for the specified SMID.
    ///
    /// Personal policy rows are created when in-app placements are received.
    /// If the policy row does not exist, this method does nothing.
    ///
    /// - Parameter smid: In-app message identifier from `inapps[].smid`.
    static func incrementInAppOpenCount(
        smid: String
    ) async {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<PersonalPolicyEntity> = PersonalPolicyEntity.fetchRequest()
                request.fetchLimit = 1
                request.predicate = NSPredicate(
                    format: "smid == %@",
                    smid
                )

                guard let entity = try context.fetch(request).first else {
                    return
                }

                entity.openCount += 1

                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Marks delivery report as sent for the specified SMID.
    ///
    /// After this flag becomes `true`, the in-app should not be included in the next
    /// unreported delivery event pass.
    ///
    /// - Parameter smid: In-app message identifier from `inapps[].smid`.
    static func setInAppReportStatus(
        smid: String
    ) async {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<PersonalPolicyEntity> = PersonalPolicyEntity.fetchRequest()
                request.fetchLimit = 1
                request.predicate = NSPredicate(
                    format: "smid == %@",
                    smid
                )

                if let entity = try context.fetch(request).first {
                    entity.deliveryReport = true
                }

                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Returns delivery report status for the specified SMID.
    ///
    /// The status is used to decide whether a delivery event still needs to be sent
    /// for a saved in-app campaign.
    ///
    /// - Parameter smid: In-app message identifier from `inapps[].smid`.
    /// - Returns: Saved delivery report status, or `nil` if the policy does not exist or loading fails.
    static func getInAppReportStatus(
        smid: String
    ) async -> Bool? {
        do {
            return try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<PersonalPolicyEntity> = PersonalPolicyEntity.fetchRequest()
                request.fetchLimit = 1
                request.predicate = NSPredicate(
                    format: "smid == %@",
                    smid
                )

                return try context.fetch(request).first?.deliveryReport
            }
        } catch {
            InAppLog.error(#function, error: error)
            return nil
        }
    }

    /// Returns in-apps whose delivery report has not been sent yet.
    ///
    /// The method finds personal policy rows with `deliveryReport == false`,
    /// takes their `smid` values, and returns saved in-app campaigns with matching `smid`.
    ///
    /// - Returns: In-app campaigns linked to personal policies with unsent delivery reports.
    static func getUnreportedInApps() async -> [InAppModel.InApp] {
        do {
            return try await inAppDatabase.performBackgroundTask { context in
                let policyRequest: NSFetchRequest<PersonalPolicyEntity> = PersonalPolicyEntity.fetchRequest()
                policyRequest.predicate = NSPredicate(
                    format: "deliveryReport == %@",
                    NSNumber(value: false)
                )

                let policies = try context.fetch(policyRequest)
                let smids = policies.compactMap { $0.smid }

                guard !smids.isEmpty else {
                    return []
                }

                let inAppRequest: NSFetchRequest<InAppEntity> = InAppEntity.fetchRequest()
                inAppRequest.predicate = NSPredicate(
                    format: "smid IN %@",
                    smids
                )

                let entities = try context.fetch(inAppRequest)

                return try entities.map {
                    try InAppMapper.toInApp(entity: $0)
                }
            }
        } catch {
            InAppLog.error(#function, error: error)
            return []
        }
    }

    /// Deletes personal display policy for the specified SMID.
    ///
    /// This removes personal counters and delivery report status for one concrete
    /// in-app message.
    ///
    /// - Parameter smid: In-app message identifier from `inapps[].smid`.
    static func deletePersonalPolicyEntity(
        smid: String
    ) async {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<PersonalPolicyEntity> = PersonalPolicyEntity.fetchRequest()
                request.fetchLimit = 1
                request.predicate = NSPredicate(
                    format: "smid == %@",
                    smid
                )

                if let entity = try context.fetch(request).first {
                    context.delete(entity)
                }

                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Deletes all personal display policy records.
    ///
    /// This removes all stored open counters and delivery report statuses.
    ///
    /// Important:
    /// This method intentionally does not use `NSBatchDeleteRequest`.
    /// Some Core Data stores, for example `NSMappedObjectStore`, do not support
    /// batch delete requests and can throw an Objective-C exception instead of a
    /// regular Swift error. Fetching objects and deleting them through the context
    /// keeps the behavior compatible with all supported persistent store types.
    static func deleteAllPersonalPolicyEntities() async {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                try deleteAllObjects(
                    of: PersonalPolicyEntity.self,
                    in: context
                )
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Deletes personal policies for the specified ACID whose SMID is no longer present.
    ///
    /// This is used after receiving a fresh placements response.
    /// Policies for the current `acid` are kept only if their `smid` still exists in
    /// the latest actual in-app list. This prevents old personal policies from
    /// remaining after campaigns are no longer available.
    ///
    /// If `smidList` is empty, all personal policies for the specified `acid` are deleted.
    ///
    /// - Parameters:
    ///   - acid: Current Altcraft identifier used to scope personal policies.
    ///   - smidList: Actual `inapps[].smid` values that should remain stored for this `acid`.
    static func deletePersonalPoliciesNotIn(
        acid: String,
        smidList: [String]
    ) async {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<PersonalPolicyEntity> = PersonalPolicyEntity.fetchRequest()

                if smidList.isEmpty {
                    request.predicate = NSPredicate(
                        format: "acid == %@",
                        acid
                    )
                } else {
                    request.predicate = NSPredicate(
                        format: "acid == %@ AND NOT (smid IN %@)",
                        acid,
                        smidList
                    )
                }

                let entities = try context.fetch(request)

                for entity in entities {
                    context.delete(entity)
                }

                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Deletes all objects of the specified Core Data entity type.
    ///
    /// This helper uses regular `fetch` + `context.delete(_:)` instead of
    /// `NSBatchDeleteRequest`.
    ///
    /// Why:
    /// - `NSBatchDeleteRequest` is faster for SQLite stores;
    /// - but it is not supported by every persistent store implementation;
    /// - unsupported stores may throw an Objective-C exception, which Swift `do/catch`
    ///   cannot catch;
    /// - regular context deletion keeps the SDK safer in production environments
    ///   where the actual store type may differ.
    ///
    /// The helper saves the context only when there are actual changes.
    ///
    /// - Parameters:
    ///   - type: Managed object subclass type to delete.
    ///   - context: Context where deletion should be performed.
    static func deleteAllObjects<T: NSManagedObject>(
        of type: T.Type,
        in context: NSManagedObjectContext
    ) throws {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.includesPropertyValues = false

        let objects = try context.fetch(request)

        for object in objects {
            context.delete(object)
        }

        if context.hasChanges {
            try context.save()
        }
    }

    /// Checks whether an in-app campaign contains the specified trigger event.
    ///
    /// Trigger events come from `placements[].options.trigger_events`.
    /// They define which SDK or custom event can start in-app display processing.
    ///
    /// - Parameters:
    ///   - inApp: In-app campaign to check.
    ///   - triggerType: Required trigger event type, for example `default` or `custom`.
    ///   - eventName: Required trigger event name, for example `launch` or `custom_event_1`.
    /// - Returns: `true` if the campaign contains a matching trigger event.
    private static func matchesTriggerEvent(
        _ inApp: InAppModel.InApp,
        triggerType: String,
        eventName: String
    ) -> Bool {
        inApp.options.triggerEvents.contains {
            $0.type == triggerType && $0.name == eventName
        }
    }

    /// Checks whether an in-app campaign matches the requested placement.
    ///
    /// Placement identifiers come from `placements[].options.placements`.
    /// They describe application locations where the in-app can be shown,
    /// for example `home_screen`.
    ///
    /// Matching rules:
    /// - if `placement` is `nil` or empty, placement filtering is skipped;
    /// - if campaign has no placement restrictions, it matches any requested placement;
    /// - if campaign contains the requested placement, it matches.
    ///
    /// - Parameters:
    ///   - inApp: In-app campaign to check.
    ///   - placement: Optional placement identifier requested by the SDK consumer.
    /// - Returns: `true` if the campaign can be used for the requested placement.
    private static func matchesPlacement(
        _ inApp: InAppModel.InApp,
        placement: String?
    ) -> Bool {
        let placements = inApp.options.placements

        guard let placement, !placement.isEmpty else {
            return true
        }

        return placements.isEmpty || placements.contains(placement)
    }

}
