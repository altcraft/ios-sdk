//
//  Constants.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// A collection of constant values used by the Core module.
///
/// Only cross-cutting Core values live here: background-task identifiers, the
/// UserDefaults prefix, Core module queue labels, Core Data model/store names,
/// JSON/query/header/method URL vocabularies, shared map keys, subscription
/// status values, Core entity names, retry tunables, and log strings.
///
/// Module-scoped constants live in their own `*Constants` namespace.
///
/// The enum itself is SPI-visible so SDK modules can reach the shared retry
/// tunables; its members stay internal unless explicitly opened below.
@_spi(_Altcraft) public enum Constants {

    /// The name of the background task for access control.
    static let bgTaskName = "AccessToBackgroundTask"

    /// The name of the periodic background task for system control.
    static let BGTaskID = "lib.Altcraft.bgTask.systemControl"

    /// Prefix used to namespace UserDefaults keys and prevent collisions with host app data.
    static let UDPrefix = "com.altcraft.ios.sdk"

    /// Centralized string constants for queue labels used in the SDK.
    enum Queues {

        // === SDK state queues ===

        static let sdkStateQueue = "com.altcraft.sdk.stateQueue"

        // === Authenticate request queues ===

        static let AuthRequestEntityQueue = "com.altcraft.authRequest.entityQueue"
        static let AuthRequestStartQueue  = "com.altcraft.authRequest.startQueue"

        // === Auth queues ===

        static let authQueue = "com.altcraft.auth.queue"

        // === Retry queues ===

        static let retryManagerSync = "com.altcraft.retry.manager.sync"
    }

    /// Query parameters used in URL requests.
    enum QueryItem {
        static let provider = "provider"
        static let matchingMode = "matching_mode"
        static let sync = "sync"
        static let subscriptionId = "subscription_id"
    }

    /// Common URL schemes used when constructing endpoints.
    enum URLScheme {
        static let http = "http"
        static let https = "https"
    }

    /// Common HTTP header field names.
    enum HTTPHeader {
        static let contentType = "Content-Type"
        static let authorization = "Authorization"
        static let requestId = "Request-ID"
    }

    /// HTTP method names.
    enum HTTPMethod {
        static let post = "POST"
        static let get = "GET"
    }

    /// Generic JSON key vocabulary shared by Core.
    enum JSONKeys {
        static let acid = "acid"
        static let startTime = "start_time"
    }

    /// Keys used in JWT payload and matching claim processing.
    enum AuthKeys {
        static let matching = "matching"
        static let rtoken = "rtoken"
        static let dbId = "db_id"
        static let email = "email"
        static let phone = "phone"
        static let profileId = "profile_id"
        static let fieldName = "field_name"
        static let fieldValue = "field_value"
        static let provider = "provider"
        static let subscriptionId = "subscription_id"
        static let matchingID = "matching_identifier"
        static let rTokenMatching = "push_sub"
    }

    /// Keys used in constructing event and request value maps.
    enum MapKeys {
        static let uid = "uid"
        static let type = "type"
        static let name = "name"
        static let provider = "provider"
        static let responseWithHttp = "response_with_http_code"
        static let token = "token"
        static let url = "url"
        static let identifier = "identifier"
        static let index = "index"
        static let link = "link"
        static let smid = "smid"
        static let allSmidKey = "allSmidKey"
    }

    /// Subscription status values.
    enum SubStatus {
        static let subscribed = "subscribed"
        static let unsubscribed = "unsubscribed"
        static let suspended = "suspended"
    }

    /// Contains the names of the Core Data entities owned by Core.
    enum EntityNames {

        static let configurationEntity = "ConfigurationEntity"
        static let authenticationEntity = "AuthenticationEntity"
        static let authRequestEntity = "AuthRequestEntity"
    }

    /// Defines constants for retry logic.
    ///
    /// SPI-visible: SDK modules read the shared retry tunables
    /// (e.g. event DAO retry caps) instead of hardcoding duplicates.
    public enum Retry {

        /// Retry cap stored in event entities (`maxRetryCount` is Int16
        /// in the Core Data models).
        public static let maxGlobalRetryCount: Int16 = 15

        /// Base backoff delay in seconds (Android parity).
        ///
        /// Mirrors the effective Android WorkManager backoff: the SDK sets
        /// `RETRY_TIME_C_WORK = 5s`, but WorkManager clamps backoff to its
        /// 10-second minimum (`MIN_BACKOFF_MILLIS`), so the delay before
        /// retry `k` is `backoffDelay * pow(2, k - 1)`:
        /// 10, 20, 40, 80, 160 seconds.
        public static let backoffDelay: Double = 10.0

        public static let maxLocalRetryCount = 5
    }

    /// A collection of constant values related to Core Data configuration.
    enum CoreData {
        static let identifier = "altcraft.Altcraft"
        static let subdirName = "Altcraft"
        static let modelName = "DataBase"
        static let coreModelName = "Core"
        static let storeFileName = "Database.sqlite"
        static let emptyModelName = "EmptyDataBase"
        static let coreStoreFileName = "Core.sqlite"
    }

    /// Core-owned SDK request names.
    enum RequestName {

        static let authorize = "auth/authorize"
    }

    /// Log-related constants for Altcraft SDK.
    enum Log {

        static let hintLog =
            "Altcraft SDK is integrated into the project. " +
            "You can enable SDK logs by setting the `enableLogging` parameter " +
            "in the SDK configuration."
    }
}
