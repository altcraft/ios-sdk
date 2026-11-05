//
//  AppConstants.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush
import AltcraftInApp
import AltcraftTarget

/// Application-wide constants.
public enum AppConstants {
    
    /// Display names for screen modes.
    enum BoxModeName {
        static let events = "events"
        static let subscribe = "subscribe"
        static let profile = "profile"
        static let target = "target"
    }
    
    /// Subscription status values used by the UI.
    public enum SubscriptionStatus {
        static let subscribed = "subscribed"
        static let unsubscribed = "unsubscribed"
        static let suspended = "suspended"
    }
}
