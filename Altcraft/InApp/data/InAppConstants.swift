//
//  InAppConstants.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Constants used by the in-app module.
///
/// `PlacementsConfig` is public since it backs the public
/// `inAppConfig` builder defaults; everything else is internal.
public enum InAppConstants {

    /// In-app module name and shared identifier.
    enum Module {

        /// Unique in-app module identifier.
        static let id = "altcraft-inapp"
    }

    /// In-app placements configuration defaults.
    public enum PlacementsConfig {

        /// Default interval between automatic in-app placements requests, in seconds.
        ///
        /// Mirrors Android `DEFAULT_PLACEMENTS_REQ_INTERVAL_MS` (30 minutes).
        public static let requestIntervalSeconds: Int64 = 30 * 60

        /// Default interval between automatic in-app placements requests, in milliseconds.
        public static let requestIntervalMs: Int64 = requestIntervalSeconds * 1000

        /// Default maximum number of in-app placements kept in local storage.
        public static let maxPlacements = 500
    }

    /// Keys used in in-app placements event payloads.
    enum PlacementsEventKeys {

        /// Event payload key for rejected company identifiers.
        static let rejectedCompanyIds = "rejectedCompanyIds"

        /// Event payload key for the number of received placements.
        static let received = "received"

        /// Event payload key for the configured placement limit.
        static let limit = "limit"
    }

    /// Defines event types for the inapp_event request.
    enum InAppEvents {

        /// Name of the in-app delivery event.
        static let delivery = "deliv"
    }

    /// Contains in-app campaign type names.
    enum InAppType {

        /// JSON in-app campaign type.
        static let json = "json"

        /// Custom in-app campaign type.
        static let custom = "custom"
    }

    /// Contains identifiers of the default in-app triggers used by the SDK.
    enum InAppDefaultTriggerType {

        static let openApp = "open_app"
        static let openPage = "open_page"
    }

    /// Names of JavaScript interfaces bridged into the in-app web view.
    enum JSInterfaceName {

        static let inAppBridge = "InAppBridge"
    }

    /// Request names for in-app API endpoints (event value "type" + log).
    enum RequestName {

        /// Request path for in-app subscribe.
        static let subscribe = "inapp/subscribe"

        /// Request path for in-app unsubscribe.
        static let unsubscribe = "inapp/unsubscribe"

        /// Request path for in-app status.
        static let status = "inapp/status"

        /// Request path for in-app event.
        static let event = "inapp/event"

        /// Request path for in-app placements.
        static let placements = "inapp/placements"
    }

    /// Predefined failure messages for in-app requests.
    enum SDKFailedMessage {

        /// Message for failed in-app subscribe request.
        static let subscribeFailed = "failed request: \(InAppConstants.RequestName.subscribe)"

        /// Message for failed in-app unsubscribe request.
        static let unsubscribeFailed = "failed request: \(InAppConstants.RequestName.unsubscribe)"

        /// Message for failed in-app status request.
        static let statusFailed = "failed request: \(InAppConstants.RequestName.status)"

        /// Message for failed in-app event request.
        static let eventFailed = "failed request: \(InAppConstants.RequestName.event)"

        /// Message for failed in-app placements request.
        static let placementsFailed = "failed request: \(InAppConstants.RequestName.placements)"
    }

    /// Queue labels used by the in-app module.
    enum Queues {

        /// Queue label for in-app placements processing.
        static let inAppPlacementsQueue = "com.altcraft.inaAppPlacements.queue"

        /// Dispatch queue label for the App Lifecycle Tracker.
        static let lifecycleTrackerQueue = "com.altcraft.app.lifecycle.tracker"

        /// Dispatch queue label for InAppEmitter state synchronization.
        static let inAppEmitterState = "com.altcraft.inappemitter.state"
    }

    /// Relative API paths used by the in-app module. The base URL is resolved
    /// internally by Core; modules only describe the endpoint suffix.
    enum UrlPath {

        /// In-app subscription endpoint path.
        static let subscribe = "/inapp/subscribe"

        /// In-app status endpoint path.
        static let status = "/inapp/status"

        /// In-app event endpoint path (the event type is appended by the builder).
        static let event = "/inapp/event"

        /// Layouts (placements) endpoint path.
        static let placements = "/inapp/placements"

        /// In-app library JS static resource path.
        static let libJs = "/inapp/v1/js/inappLibrary.js"

        /// In-app block JS static resource path.
        static let blockJs = "/inapp/v1/js/inappBlock.js"

        /// In-app block CSS static resource path.
        static let blockCss = "/inapp/v1/css/inappBlock.css"
    }

    /// In-app Core Data entity names.
    enum EntityNames {

        /// The name of the in-app subscription entity.
        static let inAppSubscribeEntity = "InAppSubscribeEntity"

        /// The name of the in-app event entity.
        static let inAppEventEntity = "InAppEventEntity"

        /// The name of the stored in-app placements state entity.
        static let inAppsEntity = "InAppsEntity"

        /// The name of the cached in-app static resources entity.
        static let inAppStaticEntity = "InAppStaticEntity"

        /// The name of the in-app campaign entity.
        static let inAppEntity = "InAppEntity"

        /// The name of the personal in-app policy entity.
        static let personalPolicyEntity = "PersonalPolicyEntity"

        /// The name of the stored in-app subscription state entity.
        static let inAppSubStateEntity = "InAppSubStateEntity"
    }

    /// In-app retry keys (identifiers for the shared retry counter/store).
    enum RetryKey {

        /// Key for in-app subscription retries.
        static let inAppSubscribe = "inAppSubscribe"

        /// Key for in-app event retries.
        static let inAppEvent = "inAppEvent"

        /// Key for in-app static resource retries.
        static let inAppStatic = "inAppStatic"

        /// Key for in-app placements retries.
        static let inAppPlacements = "inAppPlacements"
    }

    /// In-app retry queue labels (supplied to ``RetryManager``).
    enum RetryQueues {

        /// Queue label for in-app event retries.
        static let inAppEvent = "com.altcraft.retry.inAppEvent"

        /// Queue label for in-app static resource retries.
        static let inAppStatic = "group.altcraft.retry.inAppStatic"

        /// Queue label for in-app placements retries.
        static let inAppPlacements = "group.altcraft.retry.inAppPlacements"

        /// Queue label for in-app subscription retries.
        ///
        /// Shares the same label as the push subscribe queue so both run on the
        /// same shared serial retry queue (behavior preserved from the pre-split
        /// `RetryManager.subscribeQueue`).
        static let inAppSubscribe = "com.altcraft.retry.subscribe"
    }

    /// Query parameters used in URL requests.
    enum QueryItem {
        static let provider = "provider"
        static let sync = "sync"
        static let subscriptionId = "subscription_id"
    }

    /// JSON keys used by in-app module payloads.
    enum JSONKeys {
        static let acid = "acid"
        static let profileFields = "profile_fields"
        static let fields = "fields"
        static let cats = "cats"
        static let status = "status"
        static let time = "time"
        static let sync = "sync"
        static let replace = "replace"
        static let skipTriggers = "skip_triggers"
        static let catsName = "name"
        static let catsTitle = "title"
        static let catsSteady = "steady"
        static let catsActive = "active"
        static let smid = "smid"
        static let data = "data"
        static let name = "name"
        static let link = "link"
        static let code = "code"
        static let message = "message"
        static let deviceId = "device_id"
        static let lastPublish = "last_publish"
        static let subscription = "subscription"
        static let subscriptionId = "subscription_id"
        static let placementRulesChecksum = "placement_rules_checksum"
    }

    /// Keys used in constructing event and request value maps.
    enum MapKeys {
        static let type = "type"
        static let url = "url"
        static let smid = "smid"
        static let allSmidKey = "allSmidKey"
    }

    /// Subscription status values.
    enum SubStatus {
        static let subscribed = "subscribed"
        static let unsubscribed = "unsubscribed"
        static let suspended = "suspended"
    }

    /// Retry tunables for the in-app module.
    enum Retry {
        static let maxLocalRetryCount = 5
    }

    /// Prefix used to namespace UserDefaults keys.
    static let UDPrefix = "com.altcraft.ios.sdk"

    /// Core Data model/store names of the InApp module.
    enum CoreData {
        static let modelName = "InApp"
        static let storeFileName = "InApp.sqlite"
    }

    /// Cross-module notification names observed by the in-app module.
    ///
    /// The in-app and push modules must not know about each other, so the
    /// in-app module listens to push events by name only. The string value
    /// mirrors `PushConstants.NotificationCenter.pushDidReceiveResponse`
    /// — keep the two in sync.
    enum NotificationCenter {

        /// Fired when the user taps on a delivered notification.
        /// Mirrors `Notification.Name.altcraftPushDidReceive` posted by
        /// `NotificationManager` before any click processing starts.
        static let pushDidReceive = "AltcraftPushDidReceiveResponse"
    }
}
