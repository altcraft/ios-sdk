//
//  PushConstants.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Constants used by the push module.
///
/// Matches Android `internal object Constants`; only ``ProviderName`` is
/// exposed publicly since it is consumed by the Example app.
public enum PushConstants {

    /// Push module name and shared identifier.
    enum Module {

        /// Unique push module identifier.
        static let id = "altcraft-push"
    }

    /// The category identifier for rich push notifications.
    static let categoryForRichPush = "Altcraft"

    /// Keys used to extract custom values from `userInfo` payload.
    enum UserInfoKeys {

        /// Unique message identifier.
        static let uid = "_uid"

        /// Action buttons configuration key.
        static let buttons = "_buttons"

        /// Rich media attachment key.
        static let media = "_media"

        /// Link to open when tapping the notification or action button.
        static let clickUrl = "_click-url"
    }

    /// String identifiers for UI buttons and system notification actions.
    enum ButtonIdentifier {

        /// The default system action identifier used when a notification is tapped
        /// without choosing a custom action.
        static let defaultNotificationAction = "com.apple.UNNotificationDefaultActionIdentifier"

        /// The identifier for the first button.
        static let buttonOne = "button0"

        /// The identifier for the second button.
        static let buttonTwo = "button1"

        /// The identifier for the third button.
        static let buttonThree = "button2"
    }

    /// Request names for push API endpoints (event value "type" + log).
    enum RequestName {

        /// Request path for push subscribe.
        static let subscribe = "push/subscribe"

        /// Request path for push suspend.
        static let suspend = "push/suspend"

        /// Request path for push unsubscribe.
        static let unsubscribe = "push/unsubscribe"

        /// Request path for push unsuspend.
        static let unsuspend = "push/unsuspend"

        /// Request path for push status.
        static let status = "push/status"

        /// Request path for push token update.
        static let tokenUpdate = "push/update"

        /// Request path for push event.
        static let pushEvent = "event/push"
    }

    /// Predefined failure messages for push requests.
    enum SDKFailedMessage {

        /// Message for failed push subscribe request.
        static let subscribeFailed = "failed request: \(PushConstants.RequestName.subscribe)"

        /// Message for failed push suspend request.
        static let suspendFailed = "failed request: \(PushConstants.RequestName.suspend)"

        /// Message for failed push unsubscribe request.
        static let unsubscribeFailed = "failed request: \(PushConstants.RequestName.unsubscribe)"

        /// Message for failed push unsuspend request.
        static let unsuspendFailed = "failed request: \(PushConstants.RequestName.unsuspend)"

        /// Message for failed push status request.
        static let statusFailed = "failed request: \(PushConstants.RequestName.status)"

        /// Message for failed push token update request.
        static let tokenUpdateFailed = "failed request: \(PushConstants.RequestName.tokenUpdate)"

        /// Message for failed push event request.
        static let pushEventFailed = "failed request: \(PushConstants.RequestName.pushEvent)"
    }

    /// Push-related notification names and userInfo keys.
    enum NotificationCenter {

        /// Fired when a notification is about to be presented in foreground.
        static let pushWillPresent = "AltcraftPushWillPresent"

        /// Fired when the user taps or interacts with a delivered notification.
        static let pushDidReceiveResponse = "AltcraftPushDidReceiveResponse"

        /// userInfo key containing UNNotification for foreground events.
        static let notificationKey = "notification"

        /// userInfo key containing UNNotificationResponse for click events.
        static let responseKey = "response"
    }

    /// Push Core Data context names.
    enum ContextName {

        /// The name assigned to the background context used by PushSubscriptionProcess.
        static let pushSubscribe = "PushSubscribeContext"
    }

    /// Provider names used for identifying push notification services.
    ///
    /// Exposed publicly because it is part of the public push API and is
    /// consumed by the Example app.
    public enum ProviderName {

        /// The provider name for Firebase.
        public static let firebase = "ios-firebase"

        /// The provider name for APNs.
        public static let apns = "ios-apns"

        /// The provider name for HMS.
        public static let huawei = "ios-huawei"
    }

    /// Defines event types for the push_event request.
    enum PushEvents {

        /// Name of the notification delivery event.
        static let delivery = "delivery"

        /// Name of the notification opening event.
        static let open = "open"
    }

    /// PushStatusProcess request modes.
    enum StatusMode {

        /// Latest subscription overall (most recent, regardless of provider).
        static let latestSubscription = "latest_subscription"

        /// Latest subscription for a given provider (FCM, HMS, APNs, etc.).
        static let latestForProvider = "latest_for_provider"

        /// Subscription matching the current token and current provider.
        static let matchCurrentContext = "match_current_context"
    }

    /// Relative API paths used by the push module. The base URL is resolved
    /// internally by Core; modules only describe the endpoint suffix.
    enum UrlPath {

        /// Subscription endpoint path.
        static let subscribe = "/subscription/push/subscribe/"

        /// Token update endpoint path.
        static let update = "/subscription/push/update/"

        /// Push event endpoint path (the event type is appended by the builder).
        static let event = "/event/push"

        /// Un-suspend endpoint path.
        static let unsuspend = "/subscription/push/unsuspend/"

        /// Push status endpoint path.
        static let status = "/subscription/push/status/"
    }

    /// Push Core Data entity names.
    enum EntityNames {

        /// The name of the push subscription entity.
        static let subscribeEntity = "PushSubscribeEntity"

        /// The name of the push event entity.
        static let pushEventEntity = "PushEventEntity"

        /// The name of the push configuration entity.
        static let configEntity = "PushConfigEntity"

        /// The name of the processed push message entity.
        static let pushMessageEntity = "PushMessageEntity"
    }

    /// Push message deduplication limits.
    enum Dedup {

        /// Maximum number of processed message UIDs kept in the store.
        static let maxStoredUIDs = 100
    }

    /// Push retry keys (identifiers for the shared retry counter/store).
    enum RetryKey {

        /// Key for push subscription retries.
        static let pushSubscribe = "PushSubscriptionProcess"

        /// Key for push token update retries.
        static let tokenUpdate = "tokenUpdate"

        /// Key for push event retries.
        static let pushEvent = "pushEvent"
    }

    /// Push retry queue labels (supplied to ``RetryManager``).
    enum RetryQueues {

        /// Queue label for subscription retries.
        static let subscribe = "com.altcraft.retry.subscribe"

        /// Queue label for token update retries.
        static let tokenUpdate = "com.altcraft.retry.tokenUpdate"

        /// Queue label for push event retries.
        static let pushEvent = "com.altcraft.retry.pushEvent"
    }

    /// Query parameters used in URL requests.
    enum QueryItem {
        static let provider = "provider"
        static let sync = "sync"
        static let subscriptionId = "subscription_id"
    }

    /// JSON keys used by push module requests.
    enum JSONKeys {
        static let subscription = "subscription"
        static let provider = "provider"
        static let subscriptionId = "subscription_id"
        static let profileFields = "profile_fields"
        static let fields = "fields"
        static let cats = "cats"
        static let status = "status"
        static let time = "time"
        static let replace = "replace"
        static let skipTriggers = "skip_triggers"
        static let catsName = "name"
        static let catsTitle = "title"
        static let catsSteady = "steady"
        static let catsActive = "active"
        static let oldToken = "old_token"
        static let oldProvider = "old_provider"
        static let newToken = "new_token"
        static let newProvider = "new_provider"
        static let smid = "smid"
    }

    /// Keys used in constructing event and request value maps.
    enum MapKeys {
        static let uid = "uid"
        static let type = "type"
        static let provider = "provider"
        static let token = "token"
        static let identifier = "identifier"
        static let index = "index"
        static let link = "link"
    }

    /// Subscription status values.
    enum SubStatus {
        static let subscribed = "subscribed"
        static let unsubscribed = "unsubscribed"
        static let suspended = "suspended"
    }

    /// Retry tunables for the push module.
    enum Retry {
        static let maxLocalRetryCount = 5
    }

    /// Prefix used to namespace UserDefaults keys.
    static let UDPrefix = "com.altcraft.ios.sdk"

    /// Core Data model/store names of the Push module.
    enum CoreData {
        static let modelName = "Push"
        static let storeFileName = "Push.sqlite"
    }
}
