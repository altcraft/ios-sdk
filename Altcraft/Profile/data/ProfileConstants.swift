//
//  ProfileConstants.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Constants used by the profile module.
///
/// Not required by other modules, so it is internal (matches Android
/// `internal object Constants`).
internal enum ProfileConstants {

    /// Profile module name and shared identifier.
    enum Module {

        /// Unique profile module identifier.
        static let id = "altcraft-profile"
    }

    /// Request names for profile API endpoints.
    enum RequestName {

        /// Request path for profile update.
        static let update = "profile/update"
    }

    /// Queue labels used by the profile module.
    enum Queues {

        /// Queue label for sequential creation of profile update entities.
        static let profileUpdateEntityQueue = "com.altcraft.profileUpdate.entityQueue"

        /// Queue label for starting profile update processing with epoch reset support.
        static let profileUpdateStartQueue = "com.altcraft.profileUpdate.startQueue"
    }

    /// Relative API paths used by the profile module. The base URL is resolved
    /// internally by Core; modules only describe the endpoint suffix.
    enum UrlPath {

        /// Profile update endpoint path.
        static let update = "/profile/update"
    }

    /// Profile Core Data entity names.
    enum EntityNames {

        /// The name of the profile update entity.
        static let profileUpdateEntity = "ProfileUpdateEntity"
    }

    /// Profile retry keys (identifiers for the shared retry counter/store).
    enum RetryKey {

        /// Key for profile update retries.
        static let profileUpdate = "profileUpdate"
    }

    /// Profile retry queue labels (supplied to ``RetryManager``).
    enum RetryQueues {

        /// Queue label for profile update retries.
        static let profileUpdate = "com.altcraft.retry.profileUpdate"
    }

    /// JSON keys used by profile module payloads.
    enum JSONKeys {
        static let profileFields = "profile_fields"
        static let skipTriggers = "skip_triggers"
    }

    /// Retry tunables for the profile module.
    enum Retry {
        static let maxLocalRetryCount = 5
    }

    /// Core Data model/store names of the Profile module.
    enum CoreData {
        static let modelName = "Profile"
        static let storeFileName = "Profile.sqlite"
    }
}
