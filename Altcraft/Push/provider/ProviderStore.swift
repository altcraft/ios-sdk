//
//  ProviderStore.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

/// Provider configuration store for push token resolution.
///
/// The `PushProvider` module uses this to determine which of the three
/// token mechanisms (APNS / FCM / HMS) should be used to obtain
/// the current push token.
enum ProviderStore {
    /// Determines the push token mechanism.
    ///
    /// - `apns`  — Apple Push Notification service (iOS)
    /// - `fcm`   — Firebase Cloud Messaging (Android / multi-platform)
    /// - `hms`   — Huawei Mobile Services (Huawei devices)
    ///
    /// Each has its own token format:
    /// - APNS: 64-character hex string
    /// - FCM:  20+ character alphanumeric
    /// - HMS:  64-character hex string
    static func mechanism() -> String {
        #if canImport(UIKit)
        return "fcm"
        #else
        return "apns"
        #endif
    }
}
