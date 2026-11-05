//
//  TargetConstants.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Constants used by the target (mobile events) module.
///
/// Not required by other modules, so it is internal (matches Android
/// `internal object Constants`).
internal enum TargetConstants {

    /// Target module name and shared identifier.
    enum Module {

        /// Unique target module identifier.
        static let id = "altcraft-target"
    }

    /// Request names for target (mobile events) API endpoints.
    enum RequestName {

        /// Request path for mobile event.
        static let event = "event/post"
    }

    /// Keys of the mobile event payload parts.
    enum TargetEvents {

        static let TIME_ZONE          = "tz"
        static let TIME_MOB           = "t"
        static let ALTCRAFT_CLIENT_ID = "aci"
        static let MOB_EVENT_NAME     = "wn"
        static let PAYLOAD            = "wd"
        static let SMID_MOB           = "mi"
        static let MATCHING_MOB       = "ma"
        static let MATCHING_TYPE      = "mm"
        static let PROFILE_FIELDS_MOB = "pf"
        static let SUBSCRIPTION_MOB   = "sn"
        static let UTM_CAMPAIGN       = "cn"
        static let UTM_CONTENT        = "cc"
        static let UTM_KEYWORD        = "ck"
        static let UTM_MEDIUM         = "cm"
        static let UTM_SOURCE         = "cs"
        static let UTM_TEMP           = "ct"
    }

    /// Queue labels used by the target module.
    enum Queues {

        /// Queue label for sequential creation of mobile event entities.
        static let targetEventEntityQueue = "com.altcraft.mobileEvent.entityQueue"

        /// Queue label for starting mobile event processing with epoch reset support.
        static let targetEventStartQueue = "com.altcraft.mobileEvent.startQueue"
    }

    /// Relative API paths used by the target (mobile events) module. The base
    /// URL is resolved internally by Core; modules only describe the endpoint
    /// suffix.
    enum UrlPath {

        /// Mobile event endpoint path.
        static let event = "/event/post"
    }

    /// Target Core Data entity names.
    enum EntityNames {

        /// The name of the mobile event entity.
        static let targetEventEntity = "TargetEntity"
    }

    /// Target retry keys (identifiers for the shared retry counter/store).
    enum RetryKey {

        /// Key for mobile event retries.
        static let targetEvent = "mobileEvent"
    }

    /// Target retry queue labels (supplied to ``RetryManager``).
    enum RetryQueues {

        /// Queue label for mobile event retries.
        static let targetEvent = "com.altcraft.retry.mobileEvent"
    }

    /// Query parameters of the mobile event endpoint (web-event spec).
    enum WebEventQuery {
        /// Pixel ID query key; the value is the event's SID.
        static let pixelIDKey = "i"

        /// Tracker query key and its default value.
        static let trackerKey = "tr"
        static let trackerValue = "px"

        /// Event type query key and its default value.
        static let typeKey = "t"
        static let typeValue = "open"

        /// Protocol version query key and its default value.
        static let versionKey = "v"
        static let versionValue = "2"
    }

    /// Keys used in constructing event value maps.
    enum MapKeys {
        static let name = "name"
    }

    /// Retry tunables for the target module.
    enum Retry {
        static let maxLocalRetryCount = 5
    }

    /// Core Data model/store names of the Target module.
    enum CoreData {
        static let modelName = "Target"
        static let storeFileName = "Target.sqlite"
    }
}
