//
//  InAppModel.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Namespace for in-app campaign models.
enum InAppModel {

    /// Raw in-app campaign received from backend.
    ///
    /// - Parameters:
    ///   - companyId: Campaign identifier from the `id` field.
    ///   - contentUrl: URL to in-app HTML/content from the `link` field.
    ///   - isTest: Indicates whether the campaign is a test campaign from the `is_test` field.
    ///   - smid: Message identifier.
    ///   - type: In-app content type, for example `custom`, `json`, `block`.
    ///   - deadline: Campaign deadline timestamp. After this time, the in-app should not be shown.
    ///   - lastCompanyUpdate: Timestamp of the last company update.
    struct RawInApp: Codable, Sendable {
        let companyId: Int?
        let contentUrl: String
        let isTest: Bool?
        let smid: String
        let type: String
        let deadline: Int64
        let lastCompanyUpdate: Int64

        init(
            companyId: Int? = 0,
            contentUrl: String = "",
            isTest: Bool? = nil,
            smid: String = "",
            type: String = "custom",
            deadline: Int64 = 0,
            lastCompanyUpdate: Int64 = 0
        ) {
            self.companyId = companyId
            self.contentUrl = contentUrl
            self.isTest = isTest
            self.smid = smid
            self.type = type
            self.deadline = deadline
            self.lastCompanyUpdate = lastCompanyUpdate
        }

        /// JSON coding keys for the parent model.
        enum CodingKeys: String, CodingKey {
            case companyId = "id"
            case contentUrl = "link"
            case isTest = "is_test"
            case smid
            case type
            case deadline
            case lastCompanyUpdate = "last_company_update"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            self.companyId = try c.decodeIfPresent(Int.self, forKey: .companyId)
            self.contentUrl = try c.decodeIfPresent(String.self, forKey: .contentUrl) ?? ""
            self.isTest = try c.decodeIfPresent(Bool.self, forKey: .isTest)
            self.smid = try c.decodeIfPresent(String.self, forKey: .smid) ?? ""
            self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? "custom"
            self.deadline = try c.decodeIfPresent(Int64.self, forKey: .deadline) ?? 0
            self.lastCompanyUpdate = try c.decodeIfPresent(Int64.self, forKey: .lastCompanyUpdate) ?? 0
        }
    }

    /// Raw placement settings received from backend.
    ///
    /// - Parameters:
    ///   - id: Campaign identifier.
    ///   - checksum: Placement settings checksum.
    ///   - options: Placement configuration.
     struct RawPlacement: Codable, Sendable {
        let id: Int
        let checksum: String
        let options: PlacementOptions

        init(
            id: Int,
            checksum: String = "",
            options: PlacementOptions
        ) {
            self.id = id
            self.checksum = checksum
            self.options = options
        }
    }

    /// In-app placement campaign.
    ///
    /// - Parameters:
    ///   - uid: In-app unique identifier.
    ///   - companyId: Campaign identifier.
    ///   - smid: Message identifier.
    ///   - type: Campaign content type.
    ///   - contentUrl: Campaign content URL.
    ///   - checksum: Placement settings checksum.
    ///   - options: Placement configuration.
    ///   - deadline: Campaign deadline timestamp.
    ///   - isTest: Indicates whether campaign is test.
    ///   - lastCompanyUpdate: Last campaign update timestamp.
    ///   - actionTriggerName: Action trigger name.
    ///   - actionTriggerType: Action trigger type.
     struct InApp: Codable, Sendable {
        let uid: String
        let companyId: Int
        let smid: String
        let type: String
        let contentUrl: String
        let checksum: String
        let options: PlacementOptions
        let deadline: Int64
        let isTest: Bool
        let lastCompanyUpdate: Int64
        var actionTriggerName: String
        var actionTriggerType: TriggerType

        init(
            uid: String,
            companyId: Int,
            smid: String,
            type: String,
            contentUrl: String,
            checksum: String,
            options: PlacementOptions,
            deadline: Int64 = 0,
            isTest: Bool = false,
            lastCompanyUpdate: Int64,
            actionTriggerName: String = "",
            actionTriggerType: TriggerType = .custom
        ) {
            self.uid = uid
            self.companyId = companyId
            self.smid = smid
            self.type = type
            self.contentUrl = contentUrl
            self.checksum = checksum
            self.options = options
            self.deadline = deadline
            self.isTest = isTest
            self.lastCompanyUpdate = lastCompanyUpdate
            self.actionTriggerName = actionTriggerName
            self.actionTriggerType = actionTriggerType
        }
    }

    /// Placement settings.
    ///
    /// - Parameters:
    ///   - endTime: Campaign end date timestamp.
    ///   - policy: Display limit rules.
    ///   - isAnonim: Whether the campaign is available for anonymous users.
    ///   - placements: Allowed placement identifiers.
    ///   - appVersions: Allowed app versions.
    ///   - appVersionConditionRaw: Raw app version comparison condition.
    ///   - priority: Placement priority from 0 to 10.
    ///   - triggerEvents: Events that trigger the placement.
    ///   - impressionsLimit: Max impressions allowed for one device during the whole campaign.
    ///   - availability: Time-based display restrictions.
     struct PlacementOptions: Codable, Sendable {
        let endTime: Int64
        let policy: Policy?
        let isAnonim: Bool
        let placements: [String]
        let appVersions: [String]
        let appVersionConditionRaw: String?
        let priority: Int
        let triggerEvents: [TriggerEvent]
        let impressionsLimit: Int
        let availability: Availability?

        init(
            endTime: Int64,
            policy: Policy? = nil,
            isAnonim: Bool = false,
            placements: [String] = [],
            appVersions: [String] = [],
            appVersionConditionRaw: String? = nil,
            priority: Int = 0,
            triggerEvents: [TriggerEvent] = [],
            impressionsLimit: Int = 0,
            availability: Availability? = nil
        ) {
            self.endTime = endTime
            self.policy = policy
            self.isAnonim = isAnonim
            self.placements = placements
            self.appVersions = appVersions
            self.appVersionConditionRaw = appVersionConditionRaw
            self.priority = priority
            self.triggerEvents = triggerEvents
            self.impressionsLimit = impressionsLimit
            self.availability = availability
        }

        /// JSON coding keys for the parent model.
        enum CodingKeys: String, CodingKey {
            case endTime = "end_date"
            case policy = "placement_policy"
            case isAnonim = "is_anonim"
            case placements
            case appVersions = "app_versions"
            case appVersionConditionRaw = "app_version_condition"
            case priority
            case triggerEvents = "trigger_events"
            case impressionsLimit = "impressions_limit"
            case availability
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            endTime = try c.decode(Int64.self, forKey: .endTime)
            policy = try c.decodeIfPresent(Policy.self, forKey: .policy)
            isAnonim = try c.decodeIfPresent(Bool.self, forKey: .isAnonim) ?? false
            placements = try c.decodeIfPresent([String].self, forKey: .placements) ?? []
            appVersions = try c.decodeIfPresent(
                [String].self, forKey: .appVersions
            ) ?? []
            appVersionConditionRaw = try c.decodeIfPresent(
                String.self, forKey: .appVersionConditionRaw
            )
            priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 0
            triggerEvents = try c.decodeIfPresent(
                [TriggerEvent].self, forKey: .triggerEvents
            ) ?? []
            impressionsLimit = try c.decodeIfPresent(
                Int.self, forKey: .impressionsLimit
            ) ?? 0
            availability = try c.decodeIfPresent(
                Availability.self, forKey: .availability
            )
        }

        /// Parsed app version comparison condition.
        var appVersionCondition: AppVersionMatcher.Operator? {
            AppVersionMatcher.Operator.fromValue(
                appVersionConditionRaw
            )
        }
    }

    /// Placement display policy.
    ///
    /// - Parameters:
    ///   - limitBySession: Max displays per session.
    ///   - limitByTrigger: Max displays per trigger in session.
    ///   - limitByPeriod: Max displays allowed for a period.
    ///   - minIntervalSec: Min interval between displays in seconds.
     struct Policy: Codable, Sendable {
        let limitBySession: Int
        let limitByTrigger: Int
        let limitByPeriod: LimitByPeriod
        let minIntervalSec: Int64

        init(
            limitBySession: Int = 0,
            limitByTrigger: Int = 0,
            limitByPeriod: LimitByPeriod = LimitByPeriod(),
            minIntervalSec: Int64 = 0
        ) {
            self.limitBySession = limitBySession
            self.limitByTrigger = limitByTrigger
            self.limitByPeriod = limitByPeriod
            self.minIntervalSec = minIntervalSec
        }

        /// JSON coding keys for the parent model.
        enum CodingKeys: String, CodingKey {
            case limitBySession = "limit_by_session"
            case limitByTrigger = "session_trigger_limit"
            case limitByPeriod = "limit_by_period"
            case minIntervalSec = "min_interval_sec"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            limitBySession = try c.decodeIfPresent(Int.self, forKey: .limitBySession) ?? 0
            limitByTrigger = try c.decodeIfPresent(Int.self, forKey: .limitByTrigger) ?? 0
            limitByPeriod = try c.decodeIfPresent(
                LimitByPeriod.self, forKey: .limitByPeriod
            ) ?? LimitByPeriod()
            minIntervalSec = try c.decodeIfPresent(
                Int64.self, forKey: .minIntervalSec
            ) ?? 0
        }
    }

    /// Display limit for a time period.
    ///
    /// - Parameters:
    ///   - periodDays: Period length in days.
    ///   - limit: Max displays in the period.
     struct LimitByPeriod: Codable, Sendable {
        let periodDays: Int
        let limit: Int

        init(
            periodDays: Int = 0,
            limit: Int = 0
        ) {
            self.periodDays = periodDays
            self.limit = limit
        }

        /// JSON coding keys for the parent model.
        enum CodingKeys: String, CodingKey {
            case periodDays = "period_days"
            case limit
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            periodDays = try c.decodeIfPresent(Int.self, forKey: .periodDays) ?? 0
            limit = try c.decodeIfPresent(Int.self, forKey: .limit) ?? 0
        }
    }

    /// Event that can trigger placement display.
    ///
    /// - Parameters:
    ///   - type: Event type.
    ///   - name: Event name.
    ///   - delay: Delay before display in seconds.
     struct TriggerEvent: Codable, Sendable {
        let type: String
        let name: String
        let delay: Int

        init(
            type: String = "",
            name: String = "",
            delay: Int = 0
        ) {
            self.type = type
            self.name = name
            self.delay = delay
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
            delay = try c.decodeIfPresent(Int.self, forKey: .delay) ?? 0
        }
    }

    /// Placement availability rules.
    ///
    /// - Parameters:
    ///   - periods: Allowed time periods during a day.
    ///   - mdays: Allowed days of month.
    ///   - wdays: Allowed days of week.
    ///   - months: Allowed months.
    ///   - years: Allowed years.
    ///   - tz: Time zone for availability checks.
    ///   - wdayOrders: Allowed ordinal numbers of weekdays in a month.
     struct Availability: Codable, Sendable {
        let periods: [TimePeriod]
        let mdays: [Int]
        let wdays: [Int]
        let months: [Int]
        let years: [Int]
        let tz: String
        let wdayOrders: [Int]

        init(
            periods: [TimePeriod] = [],
            mdays: [Int] = [],
            wdays: [Int] = [],
            months: [Int] = [],
            years: [Int] = [],
            tz: String = "",
            wdayOrders: [Int] = []
        ) {
            self.periods = periods
            self.mdays = mdays
            self.wdays = wdays
            self.months = months
            self.years = years
            self.tz = tz
            self.wdayOrders = wdayOrders
        }

        /// JSON coding keys for the parent model.
        enum CodingKeys: String, CodingKey {
            case periods
            case mdays
            case wdays
            case months
            case years
            case tz
            case wdayOrders = "wdayords"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            periods = try container.decodeIfPresent([TimePeriod].self, forKey: .periods) ?? []
            mdays = try container.decodeIfPresent([Int].self, forKey: .mdays) ?? []
            wdays = try container.decodeIfPresent([Int].self, forKey: .wdays) ?? []
            months = try container.decodeIfPresent([Int].self, forKey: .months) ?? []
            years = try container.decodeIfPresent([Int].self, forKey: .years) ?? []
            tz = try container.decodeIfPresent(String.self, forKey: .tz) ?? ""
            wdayOrders = try container.decodeIfPresent([Int].self, forKey: .wdayOrders) ?? []
        }
    }

    /// Daily allowed time period.
    ///
    /// - Parameters:
    ///   - from: Start time.
    ///   - to: End time.
     struct TimePeriod: Codable, Sendable {
        let from: TimePoint
        let to: TimePoint

        init(
            from: TimePoint = TimePoint(),
            to: TimePoint = TimePoint()
        ) {
            self.from = from
            self.to = to
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            self.from = try c.decodeIfPresent(TimePoint.self, forKey: .from) ?? TimePoint()
            self.to = try c.decodeIfPresent(TimePoint.self, forKey: .to) ?? TimePoint()
        }
    }

    /// Time of day.
    ///
    /// - Parameters:
    ///   - hour: Hour value.
    ///   - min: Minute value.
     struct TimePoint: Codable, Sendable {
        let hour: Int
        let min: Int

        init(
            hour: Int = 0,
            min: Int = 0
        ) {
            self.hour = hour
            self.min = min
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            hour = try c.decodeIfPresent(Int.self, forKey: .hour) ?? 0
            min = try c.decodeIfPresent(Int.self, forKey: .min) ?? 0
        }
    }

    /// Event trigger type.
    ///
    /// - `default`: Default SDK trigger.
    /// - `custom`: Custom application trigger.
     enum TriggerType: String, Codable, Sendable {
        case `default` = "default"
        case custom = "custom"

        /// Returns a trigger type for the provided raw value.
        ///
        /// - Parameter value: Raw trigger type string.
        /// - Returns: Parsed trigger type or `.custom` if the value is unknown.
        static func fromValue(_ value: String?) -> TriggerType {
            guard let value else { return .custom }
            return TriggerType(rawValue: value.lowercased()) ?? .custom
        }
    }

    /// In-app display trigger.
    ///
    /// - Parameters:
    ///   - name: Trigger name.
    ///   - type: Trigger type.
     struct InAppTrigger: Codable, Sendable {
        let name: String
        let type: TriggerType

        init(
            name: String,
            type: TriggerType = .custom
        ) {
            self.name = name
            self.type = type
        }
    }

    /// Static resources required for In-App rendering.
    ///
    /// Contains the in-app library JavaScript, block JavaScript, and block CSS
    /// that are injected into the web view before displaying in-app content.
    struct InAppStaticProcess {
        let inAppLibraryJs: String
        let blockJs: String
        let blockCss: String
    }

    /// Represents supported in-app event types.
    ///
    /// - delivery: In-app message content was delivered to the SDK.
    /// - show: In-app message was displayed.
    /// - click: User clicked an in-app message element.
    /// - error: Error occurred while processing or displaying an in-app message.
    /// - close: In-app message was closed.
    /// - ready: JavaScript in the in-app web view is ready and has sent the ready signal.
    enum InAppEventType: String, Codable, Sendable {
        case delivery = "deliv"
        case show = "show"
        case click = "click"
        case error = "error"
        case close = "close"
        case ready = "ready"
    }

    /// In-app event received from JavaScript.
    struct InAppEventProcess: Codable, Sendable {
        let type: InAppEventType
        let payload: RequestModel.InAppEventData?
    }

    /// Persisted in-app synchronization state.
    ///
    /// Created from response metadata and current request context.
    ///
    /// - Parameters:
    ///   - acid: Altcraft identifier.
    ///   - deviceId: Device identifier.
    ///   - lastRequestTime: Last request timestamp.
    ///   - lastPublish: Last in-app publish timestamp.
    ///   - placementRulesChecksum: Placement rules checksum.
    struct InAppsState: Sendable {
        let acid: String
        let deviceId: String
        let lastRequestTime: Int64
        let lastPublish: Int64
        let placementRulesChecksum: String
    }

    /// Response containing in-app notification content.
    ///
    /// - Parameters:
    ///   - content: In-app notification content.
    ///   - images: Image links used in the in-app notification content.
    ///   - displayType: Native in-app display type received from the backend.
    struct InAppContent: Codable, Sendable {
        let content: String
        let images: [String]
        let displayType: String

        init(
            content: String,
            images: [String],
            displayType: String
        ) {
            self.content = content
            self.images = images
            self.displayType = displayType
        }

        /// JSON coding keys for the parent model.
        enum CodingKeys: String, CodingKey {
            case content
            case images = "images_links"
            case displayType = "display_type"
        }
    }
}
