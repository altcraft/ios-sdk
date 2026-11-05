//
//  InAppMapper.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Maps backend, runtime, and persisted in-app representations.
///
/// `InAppMapper` is responsible for converting in-app campaign data between
/// backend response models, runtime models, and Core Data entities.
///
/// The mapper performs the following conversions:
/// - combines raw in-app content with the corresponding placement configuration;
/// - creates runtime in-app models used by display and policy checks;
/// - creates test in-app models with default placement configuration;
/// - persists runtime models into Core Data entities;
/// - restores runtime models from Core Data entities.
///
/// Nested placement values such as placements, trigger events, application
/// versions, policies, and availability settings are stored as encoded JSON data.
///
/// Primitive placement values such as priority, end date, anonymous availability,
/// app version condition, and impressions limit are stored directly in Core Data.
@available(iOSApplicationExtension, unavailable)
enum InAppMapper {

    /// Combines raw in-app content and placement configuration into a runtime model.
    ///
    /// Placement options are copied from the backend response without modification,
    /// including display restrictions such as priority, policy, availability,
    /// app version condition, and impressions limit.
    ///
    /// The first configured trigger event is copied into the runtime action
    /// trigger fields. These values may later be replaced by the trigger that
    /// actually caused the campaign to be processed.
    ///
    /// - Parameters:
    ///   - rawInApp: Raw in-app content received from the backend.
    ///   - rawPlacement: Raw placement configuration associated with the same campaign.
    /// - Returns: Runtime in-app model ready for persistence and processing.
    static func toInApp(
        rawInApp: InAppModel.RawInApp,
        rawPlacement: InAppModel.RawPlacement
    ) -> InAppModel.InApp {
        let actionTrigger = rawPlacement.options.triggerEvents.first

        return InAppModel.InApp(
            uid: UUID().uuidString,
            companyId: rawInApp.companyId ?? 0,
            smid: rawInApp.smid,
            type: rawInApp.type,
            contentUrl: rawInApp.contentUrl,
            checksum: rawPlacement.checksum,
            options: rawPlacement.options,
            deadline: rawInApp.deadline,
            isTest: false,
            lastCompanyUpdate: rawInApp.lastCompanyUpdate,
            actionTriggerName: actionTrigger?.name ?? "",
            actionTriggerType: InAppModel.TriggerType.fromValue(
                actionTrigger?.type
            )
        )
    }

    /// Converts a raw test in-app response into a runtime test model.
    ///
    /// Test in-app messages do not use persisted placement restrictions.
    /// They therefore receive an empty placement configuration and are marked
    /// with `isTest = true`.
    ///
    /// Placement restrictions such as policy, availability, application versions,
    /// app version condition, trigger events, and impressions limit are disabled
    /// for test in-app messages.
    ///
    /// - Parameter rawInApp: Raw test in-app content received from the backend.
    /// - Returns: Runtime test in-app model.
    static func rawToTestInApp(
        _ rawInApp: InAppModel.RawInApp
    ) -> InAppModel.InApp {
        InAppModel.InApp(
            uid: UUID().uuidString,
            companyId: rawInApp.companyId ?? 0,
            smid: rawInApp.smid,
            type: rawInApp.type,
            contentUrl: rawInApp.contentUrl,
            checksum: "",
            options: InAppModel.PlacementOptions(
                endTime: 0,
                policy: nil,
                isAnonim: false,
                placements: [],
                appVersions: [],
                appVersionConditionRaw: nil,
                priority: 0,
                triggerEvents: [],
                impressionsLimit: 0,
                availability: nil
            ),
            deadline: rawInApp.deadline,
            isTest: true,
            lastCompanyUpdate: rawInApp.lastCompanyUpdate,
            actionTriggerName: "",
            actionTriggerType: .custom
        )
    }

    /// Writes a runtime in-app model into a Core Data entity.
    ///
    /// Primitive values are stored directly in Core Data attributes.
    /// Nested collections and structures are encoded as JSON data.
    ///
    /// The following placement values are stored directly:
    /// - priority;
    /// - end date;
    /// - anonymous campaign flag;
    /// - app version condition;
    /// - impressions limit.
    ///
    /// The following placement values are encoded as JSON:
    /// - placements;
    /// - trigger events;
    /// - application versions;
    /// - policy;
    /// - availability.
    ///
    /// The app version condition is persisted separately from the application
    /// versions list so version comparison rules survive database persistence.
    ///
    /// The impressions limit is persisted explicitly to preserve the backend
    /// `impressions_limit` value through the complete
    /// backend → runtime model → database → runtime model flow.
    ///
    /// - Parameters:
    ///   - item: Runtime in-app model to persist.
    ///   - entity: Core Data entity that receives the model values.
    /// - Throws: An encoding error when a nested value cannot be serialized.
    static func apply(
        _ item: InAppModel.InApp,
        to entity: InAppEntity
    ) throws {
        entity.uid = item.uid
        entity.companyId = Int32(item.companyId)
        entity.smid = item.smid
        entity.type = item.type
        entity.contentUrl = item.contentUrl
        entity.checksum = item.checksum
        entity.deadline = item.deadline
        entity.lastCompanyUpdate = item.lastCompanyUpdate
        entity.actionTriggerName = item.actionTriggerName
        entity.actionTriggerType = item.actionTriggerType.rawValue

        entity.priority = Int16(
            item.options.priority
        )
        entity.endDate = item.options.endTime
        entity.isAnonim = item.options.isAnonim
        entity.appVersionCondition = item.options.appVersionConditionRaw
        entity.impressionsLimit = Int32(
            item.options.impressionsLimit
        )

        entity.placements = try encodeInAppValue(
            item.options.placements
        )

        entity.triggerEvents = try encodeInAppValue(
            item.options.triggerEvents
        )

        entity.appVersions = try encodeInAppValue(
            item.options.appVersions
        )

        entity.policy = try encodeInAppValue(
            item.options.policy
        )

        entity.availability = try encodeInAppValue(
            item.options.availability
        )
    }

    /// Restores a runtime in-app model from a Core Data entity.
    ///
    /// Nested JSON values are decoded into their corresponding runtime types.
    /// Missing optional binary values are restored using safe defaults.
    ///
    /// Primitive placement values are restored directly from Core Data attributes.
    ///
    /// The app version condition is restored separately from the application
    /// versions list and passed back into `PlacementOptions.appVersionConditionRaw`.
    /// This allows `Check.Version` to apply the original backend comparison rule
    /// after the campaign has been loaded from local storage.
    ///
    /// The impressions limit is restored from the Core Data attribute and
    /// propagated into `PlacementOptions.impressionsLimit`.
    ///
    /// - Parameter entity: Persisted Core Data in-app entity.
    /// - Returns: Runtime in-app model restored from local storage.
    /// - Throws: A decoding error when persisted nested data is invalid.
    static func toInApp(
        entity: InAppEntity
    ) throws -> InAppModel.InApp {
        let placements = try decodeInAppValue(
            [String].self,
            from: entity.placements
        ) ?? []

        let triggerEvents = try decodeInAppValue(
            [InAppModel.TriggerEvent].self,
            from: entity.triggerEvents
        ) ?? []

        let appVersions = try decodeInAppValue(
            [String].self,
            from: entity.appVersions
        ) ?? []

        let policy = try decodeInAppValue(
            InAppModel.Policy.self,
            from: entity.policy
        )

        let availability = try decodeInAppValue(
            InAppModel.Availability.self,
            from: entity.availability
        )

        let options = InAppModel.PlacementOptions(
            endTime: entity.endDate,
            policy: policy,
            isAnonim: entity.isAnonim,
            placements: placements,
            appVersions: appVersions,
            appVersionConditionRaw: entity.appVersionCondition,
            priority: Int(entity.priority),
            triggerEvents: triggerEvents,
            impressionsLimit: Int(entity.impressionsLimit),
            availability: availability
        )

        return InAppModel.InApp(
            uid: entity.uid ?? "",
            companyId: Int(entity.companyId),
            smid: entity.smid ?? "",
            type: entity.type ?? "",
            contentUrl: entity.contentUrl ?? "",
            checksum: entity.checksum ?? "",
            options: options,
            deadline: entity.deadline,
            isTest: false,
            lastCompanyUpdate: entity.lastCompanyUpdate,
            actionTriggerName: entity.actionTriggerName ?? "",
            actionTriggerType: InAppModel.TriggerType.fromValue(
                entity.actionTriggerType
            )
        )
    }
}
