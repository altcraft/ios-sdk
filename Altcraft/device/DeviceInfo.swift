//
//  DeviceInfo.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import UIKit
import AdSupport

/// Provides device-related information, including system details, timezone, and advertising ID.
class DeviceInfo {
    
    /// Retrieves detailed device information.
    ///
    /// This function collects various device attributes, including:
    /// - Model, name, OS version.
    /// - Time zone, language settings.
    /// - Advertising ID and tracking permission.
    ///
    /// If an error occurs, an empty dictionary is returned.
    ///
    /// - Returns: A dictionary containing device information. Keys include:
    ///   - `_os` (Operating System Name)
    ///   - `_os_tz` (Time Zone)
    ///   - `_ad_track` (Ad Tracking Permission)
    ///   - `_os_language` (Device Language)
    ///   - `_device_type` (Device Type)
    ///   - `_device_model` (Device Model)
    ///   - `_device_name` (Device Name)
    ///   - `_os_ver` (OS Version)
    ///   - `_ad_id` (Advertising ID, if available)
    static func getDeviceFields() -> [String: Any] {
        var deviceInfo: [String: Any] = [:]
            let deviceModel = deviceIdentifier()
            let deviceName = UIDevice.current.name
            let osVersion = UIDevice.current.systemVersion
            let timeZone = getTimeZoneOffset()
            let language = Locale.current.languageCode ?? "unknown"
            let (adId, adTrack) = getAdvertisingIdInfo()
            deviceInfo["_os"] = "IOS"
            deviceInfo["_os_tz"] = timeZone
            deviceInfo["_ad_track"] = adTrack
            deviceInfo["_os_language"] = language
            deviceInfo["_device_type"] = "Mobile"
            deviceInfo["_device_model"] = deviceModel
            deviceInfo["_device_name"] = deviceName
            deviceInfo["_os_ver"] = osVersion
            if let adId = adId {
                deviceInfo["_ad_id"] = adId
            }
        
        return deviceInfo
    }
    
    /// Returns the internal device identifier (e.g., "iPhone14,7").
    ///
    /// Uses `uname()` to read the hardware model from `utsname.machine`.
    /// This value can be mapped to a specific iPhone/iPad model using external sources.
    ///
    /// - Returns: A string like "iPhone14,7", or "unknown" if unavailable.
    static func deviceIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
    }
    
    /// Retrieves the advertising ID and user preference for ad tracking.
    ///
    /// - Returns: A tuple containing the advertising ID (or `nil` if unavailable) and a boolean indicating
    ///   whether ad tracking is allowed (`true` if tracking is enabled, `false` otherwise).
    static func getAdvertisingIdInfo() -> (String?, Bool) {
        guard ASIdentifierManager.shared().isAdvertisingTrackingEnabled else {
            return (nil, false)
        }
        
        let adId = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        return (adId, true)
    }
    
    /// Retrieves the time zone offset in the format "+hhmm" or "-hhmm".
    ///
    /// - Returns: A string representing the time zone offset in the specified format.
    ///   Returns "+0000" in case of an error.
    static func getTimeZoneOffset() -> String {
        let timeZone = TimeZone.current
        let secondsFromGMT = timeZone.secondsFromGMT()
        let hours = abs(secondsFromGMT / 3600)
        let minutes = abs((secondsFromGMT % 3600) / 60)
        let sign = secondsFromGMT >= 0 ? "+" : "-"
        
        return String(format: "%@%02d%02d", sign, hours, minutes)
    }
    
    /// Returns mobile-event timezone offset in minutes as a signed integer.
    /// Mirrors Android: -(hours * 60 + minutes).
    /// On any failure returns 0.
    @inline(__always)
    func getTimeZoneForMobEvent() -> Int16 {
        let seconds = TimeZone.current.secondsFromGMT()
        let minutes = seconds / 60
        let value = -minutes
        if value > Int(Int16.max) { return Int16.max }
        if value < Int(Int16.min) { return Int16.min }
        return Int16(value)
    }
}
