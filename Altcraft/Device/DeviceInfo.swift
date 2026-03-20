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
final class DeviceInfo {

    /// Retrieves detailed device information in a sendable representation.
    ///
    /// - Returns: `DeviceFields` containing device metadata.
    @MainActor
    static func getDeviceFields() -> DeviceFields {
        let deviceModel = deviceIdentifier()
        let timeZone = getTimeZoneOffset()
        let language = Locale.current.languageCode ?? "unknown"
        let (adId, adTrack) = getAdvertisingIdInfo()

        let deviceName = UIDevice.current.name
        let osVersion = UIDevice.current.systemVersion

        return DeviceFields(
            os: "IOS",
            osTimeZone: timeZone,
            adTrack: adTrack,
            osLanguage: language,
            deviceType: "mob",
            deviceModel: deviceModel,
            deviceName: deviceName,
            osVersion: osVersion,
            adId: adId
        )
    }

    /// Backwards-compatible completion-based API.
    ///
    /// - Parameter completion: A closure receiving device fields dictionary.
    static func getDeviceFields(completion: @escaping ([String: Any]) -> Void) {
        let cb = CallbackBox<[String: Any]>(completion)
        Task { @MainActor in
            cb.call(getDeviceFields().asDictionary())
        }
    }

    /// Returns the internal device identifier (e.g., "iPhone14,7").
    ///
    /// Uses `uname()` to read the hardware model from `utsname.machine`.
    ///
    /// - Returns: A string like "iPhone14,7", or "unknown" if unavailable.
    static func deviceIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? "unknown"
            }
        }
    }

    /// Retrieves the advertising ID and user preference for ad tracking.
    ///
    /// - Returns: A tuple containing the advertising ID (or `nil` if unavailable) and a boolean indicating
    ///   whether ad tracking is allowed.
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
    static func getTimeZone() -> Int16 {
        let seconds = TimeZone.current.secondsFromGMT()
        let minutes = seconds / 60
        let value = -minutes

        if value > Int(Int16.max) { return Int16.max }
        if value < Int(Int16.min) { return Int16.min }
        return Int16(value)
    }
}
