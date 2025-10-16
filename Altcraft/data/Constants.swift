//
//  Constants.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

/// A collection of constant values used throughout the application.
///
/// The `Constants` enum contains various static properties and nested enums that define constant values
/// for categories, background tasks, provider names, event names, request names, entity names, and retry logic.
public enum Constants {
    
    /// Provider names used for identifying push notification services.
    public enum ProviderName {

        /// The provider name for Firebase.
        public static let firebase = "ios-firebase"

        /// The provider name for APNs.
        public static let apns = "ios-apns"

        /// The provider name for HMS.
        public static let huawei = "ios-huawei"
    }

    /// The category identifier for rich push notifications.
    static let categoryForRichPush = "Altcraft"
    
    /// The name of the background task for access control.
    
    static let bgTaskName = "AccessToBackgroundTask"
    
    /// The name of the periodic background task for system control.
    static let BGTaskID = "lib.Altcraft.bgTask.systemControl"
    
    /// Centralized string constants for queue labels used in the SDK.
    /// Helps to avoid duplication and typos when creating DispatchQueue instances.
    enum Queues {
        
        // === Subscribe queues ===
        
        /// Queue label for sequential creation of subscription entities.
        static let subscribeEntityQueue = "com.altcraft.subscribe.entityQueue"
        
        /// Queue label for starting subscription processing with epoch reset support.
        static let subscribeStartQueue  = "com.altcraft.subscribe.startQueue"
        
        /// Queue label for synchronizing internal state and flags.
        static let subscribeSyncQueue   = "com.altcraft.subscribe.syncQueue"
        
        // === Update queues ===
        
        /// Queue label for token update operations.
        static let tokenUpdateQueue = "com.altcraft.tokenUpdateQueue"
        
        // === Push Event queues ===
        
        /// Queue label for push event processing.
        static let pushEventQueue = "com.altcraft.pushEventQueue"
        
        // === Mobile Event queues ===
        
        /// Queue label for sequential creation of mobile event entities.
        static let mobileEventEntityQueue = "com.altcraft.mobileEvent.entityQueue"
        
        /// Queue label for starting subscription processing with epoch reset support.
        static let mobileEventStartQueue  = "com.altcraft.mobileEvent.startQueue"
        
        /// Queue label for synchronizing internal state and flags.
        static let mobileEventSyncQueue   = "com.altcraft.mobileEvent.syncQueue"
        
        // === Retry queues ===
        
        /// Queue label for subscription retries.
        static let retrySubscribeQueue = "com.altcraft.retry.subscribe"
        
        /// Queue label for token update retries.
        static let retryTokenUpdateQueue = "com.altcraft.retry.tokenUpdate"
        
        /// Queue label for push event retries.
        static let retryPushEventQueue = "com.altcraft.retry.pushEvent"
        
        /// Queue label for mobile event retries.
        static let retryMobileEventQueue = "com.altcraft.retry.mobileEvent"
        
        
        static let retryManagerSync = "com.altcraft.retry.manager.sync"
    }
    
    /// A namespace for commonly used Core Data context names.
    enum ContextName {
        /// The name assigned to the background context used by PushSubscribe.
        static let pushSubscribe = "PushSubscribeContext"
    }

    /// Query parameters used in URL requests.
    public enum QueryItem {
        /// Push provider (ios-apns, ios-firebase, ios-huawey).
        static let provider = "provider"
        
        /// Matching mode for authentication or tracking.
        static let matchingMode = "matching_mode"
        
        /// Sync flag for subscription.
        static let sync = "sync"
        
        /// Device token value.
        static let subscriptionId = "subscription_id"
    }
    
    /// Common URL schemes used when constructing endpoints.
    public enum URLScheme {
        /// The `http` scheme.
        public static let http = "http"

        /// The `https` scheme.
        public static let https = "https"
    }
    
    /// Common HTTP header field names.
    public enum HTTPHeader {
        /// Header for content type (e.g., application/json).
        static let contentType = "Content-Type"
        
        /// Header for authorization token.
        static let authorization = "Authorization"
        
        /// Header for request identifier.
        static let requestId = "Request-ID"
    }
    
    /// HTTP method names.
    public enum HTTPMethod {
        /// POST method.
        static let post = "POST"
        
        /// GET method.
        static let get = "GET"
    }
 
    ///Enum representing the keys used in JSON responses or requests.
    
    public enum JSONKeys {
        /// The key for the profile ID in JSON.
        static let profileId = "profile_id"
        
        /// The key for the resource token in JSON.
        static let resourceToken = "resource_token"
        
        /// The key for the list of subscriptions in JSON.
        static let subscription = "subscription"
        
        /// The key for the provider name in JSON.
        static let provider = "provider"
        
        /// The key for the subscription ID in JSON.
        static let subscriptionId = "subscription_id"
        
        /// The key for subscribe status in JSON.
        static let subscribe = "subscribe"
        
        /// The key for unsubscribe status in JSON.
        static let unsubscribe = "unsubscribe"
        
        /// The key for a generic ID in JSON.
        static let id = "id"
        
        /// The key for profileFields in JSON.
        static let profileFields = "profile_fields"
        
        /// The key for fields in JSON.
        static let fields = "fields"
        
        /// The key for categories in JSON.
        static let cats = "cats"
        
        /// The key for the status in JSON.
        static let status = "status"
        
        /// The key for time in JSON.
        static let time = "time"
        
        /// The key for replace flag in JSON.
        static let replace = "replace"
        
        /// The key for skip triggers flag in JSON.
        static let skipTriggers = "skip_triggers"
        
        /// The key for сategory ID in JSON.
        static let catsName = "name"
        
        /// The key for сategory name in JSON.
        static let catsTitle = "title"
        
        ///A flag key indicating that the category is locked for modification.
        static let catsSteady = "steady"
        
        /// The key for category active status in JSON.
        static let catsActive = "active"
    
        
        /// The key for the old token in update JSON.
         static let oldToken = "old_token"

         /// The key for the old provider in update JSON.
         static let oldProvider = "old_provider"

         /// The key for the new token in update JSON.
         static let newToken = "new_token"

         /// The key for the new provider in update JSON.
         static let newProvider = "new_provider"
        
        /// The key for the push event ID (smid).
        static let smid = "smid"
    }
    
    /// Keys used in JWT payload and matching claim processing.
    internal enum AuthKeys {
        /// JWT payload key that contains the raw "matching" claim (JSON string).
        static let matching = "matching"
        
        /// Database ID used for matching.
        static let dbId = "db_id"
        
        /// Profile email used for matching.
        static let email = "email"
        
        /// Profile phone number used for matching.
        static let phone = "phone"
        
        /// Profile ID used for matching.
        static let profileId = "profile_id"
        
        /// Custom field name used for matching.
        static let fieldName = "field_name"
        
        /// Custom field value used for matching.
        static let fieldValue = "field_value"
        
        /// Provider code (if matching requires it).
        static let provider = "provider"
        
        /// Subscription ID used for matching.
        static let subscriptionId = "subscription_id"
        
        /// Composed value key used when building a normalized string.
        static let matchingID = "matching_identifier"
    }
    
    /// Keys used to extract custom values from `userInfo` payload.
    internal enum UserInfoKeys {
        /// Unique message identifier.
        static let uid = "_uid"

        /// Action buttons configuration key.
        static let buttons = "_buttons"

        /// Rich media attachment key.
        static let media = "_media"
        
        /// Link to open when tapping the notification or action button.
        static let clickUrl = "_click-url"
    }
    
    /// Keys used in constructing event and request value maps.
    public enum MapKeys {
        /// Push event identifier key.
        static let uid = "uid"

        /// Push event type key.
        static let type = "type"
        
        /// Mobile event name  key.
        static let name = "name"
        
        ///Push Provider key.
        static let provider = "provider"
        
        ///Provides access to the `value` containing the HTTP status code and the server response.
        static let responseWithHttp = "response_with_http_code"
        
        ///Push Token key
        static let token = "token"
        
        /// URL value key.
        static let url = "url"
        
        /// Button identifier key.
        static let identifier = "identifier"
        
        /// Button index key.
        static let index = "index"
        
        ///Link value key.
        static let link = "link"
    }

    /// Subscription status values.
    enum Status: String {
        /// Active subscription.
        case subscribe = "subscribed"
        
        /// User manually unsubscribed.
        case unsubscribe = "unsubscribed"
        
        /// Subscription is temporarily suspended.
        case suspend = "suspended"
    }
    
    /// Enum representing function codes for different processes.
    enum FunctionsCode {
        /// The function code for the subscribe process.
        static let SS = "startSubscribe()"
        
        /// The function code for the update process.
        static let SU = "startUpdate()"
        
        /// The function code for the hubLink  process.
        static let PE = "sendPushEvent()"
        
        /// The function code for the hubLink  process.
        static let ME = "sendMobileEvent()"
    }
    
    /// Defines event types for the push_event request.
    enum PushEvents {
        
        /// Name of the notification delivery event.
        static let delivery = "delivery"
        
        /// Name of the notification opening event.
        static let open = "open"
    }
    
    enum MobileEvents {
        static let TIME_ZONE          = "tz"
        static let TIME_MOB           = "t"
        static let ALTCRAFT_CLIENT_ID = "aci"
        static let MOB_EVENT_NAME     = "wn"
        static let PAYLOAD            = "wd"
        static let SMID_MOB           = "mi"
        static let MATCHING_MOB       = "ma"
        static let MATCHING_TYPE      = "mm"   // NEW
        static let PROFILE_FIELDS_MOB = "pf"
        static let SUBSCRIPTION_MOB   = "sn"
        static let UTM_CAMPAIGN       = "cn"
        static let UTM_CONTENT        = "cc"
        static let UTM_KEYWORD        = "ck"
        static let UTM_MEDIUM         = "cm"
        static let UTM_SOURCE         = "cs"
        static let UTM_TEMP           = "ct"
    }

    /// Contains the names of the entities used in Core Data.
    enum EntityNames {
        
        /// The name of the configuration entity.
        static let configEntityName = "ConfigurationEntity"
        
        /// The name of the push subscription entity.
        static let subscribeEntityName = "SubscribeEntity"
        
        /// The name of the push event entity.
        static let pushEventEntityName = "PushEventEntity"
        
        /// The name of the mobile event entity.
        static let mobileEventEntityName = "MobileEventEntity"
    }

    /// Contains the string identifiers for UI buttons and system notification actions.
    enum ButtonIdentifier {
        
        /// The default system action identifier used when a notification is tapped without choosing a custom action.
        static let defaultNotificationAction = "com.apple.UNNotificationDefaultActionIdentifier"
        
        /// The identifier for the first button.
        static let buttonOne = "button0"
        
        /// The identifier for the second button.
        static let buttonTwo = "button1"
        
        /// The identifier for the third button.
        static let buttonThree = "button2"
    }
    
    /// Defines constants for retry logic.
    enum Retry {
        
        /// Maximum number of request attempts.
        static let maxGlobalRetryCount = 15
        
        /// The initial delay for retries, in seconds.
        static let initialDelay = 2.5
        
        /// The initial retry count.
        static let initialRetryCount = 0
        
        /// The maximum number of repetitions of execution after activating the request in the function.
        static let maxLocalRetryCount = 5
    }
    
    /// A collection of constant values related to Core Data configuration.
    ///
    /// This enum provides static constants used for defining the Core Data stack,
    /// including database names, model identifiers, and file paths.
    enum CoreData {
        /// The bundle identifier for the Core Data framework.
         static let identifier = "altcraft.Altcraft"
        
        /// The name of the Core Data model.
         static let modelName = "DataBase"
        
        /// The name of the persistent store file.
         static let storeFileName = "Database.sqlite"
        
        /// The name of an empty Core Data model used as a fallback.
         static let emptyModelName = "EmptyDataBase"
    }
    
    /// A namespace for predefined SDK request names.
    enum RequestName {
        /// Request path for push unsuspend.
        static let unsuspend = "push/unsuspend"
        
        /// Request path for push subscribe.
        static let subscribe = "push/subscribe"
        
        /// Request path for push status.
        static let status = "push/status"
        
        /// Request path for push token update.
        static let update = "push/update"
        
        /// Request path for push event.
        static let pushEvent = "event/push"
        
        /// Request path for mobile event.
        static let mobileEvent = "event/post"
    }

    /// A namespace for predefined SDK success messages.
    enum SDKSuccessMessage {
        /// Message for successful completion of the subscription request.
        static let subscribeSuccess = "successful request: \(RequestName.subscribe)"

        /// Message for successful completion of the token update request.
            static let tokenUpdateSuccess = "successful request: \(RequestName.update)"
        
        /// Message for successful completion of the push unsuspend request.
        static let pushUnSuspendSuccess = "successful request: \(RequestName.unsuspend)"
        
        /// Message for successful completion of the token update request.
        static let statusSuccess = "successful request: \(RequestName.status)"

        /// Message for successful delivery of the push event.
        static let pushEventDelivered = "successful request: \(RequestName.pushEvent). Type: "
        
        /// Message for successful delivery of the mobile event.
        static let mobileEventDelivered = "successful request: \(RequestName.mobileEvent). Name: "
    }
   
    /// Status request modes.
    enum StatusMode {
        /// Latest subscription overall (most recent, regardless of provider).
        static let latestSubscription = "latest_subscription"

        /// Latest subscription for a given provider (FCM, HMS, APNs, etc.).
        static let latestForProvider = "latest_for_provider"

        /// Subscription matching the current token and current provider.
        static let matchCurrentContext = "match_current_context"
    }
}
