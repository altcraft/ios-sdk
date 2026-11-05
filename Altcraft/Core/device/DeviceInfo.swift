//
//  DeviceInfo.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import UIKit

/// Provides device-related information, including system details and timezone.
@_spi(_Altcraft) public final class DeviceInfo {
    /// Retrieves detailed device information in a sendable representation.
    ///
    /// - Returns: `DeviceFields` containing device metadata.
    @available(iOSApplicationExtension, unavailable)
    @MainActor
    static func getDeviceFields() -> DeviceFields {
        let deviceModel = deviceIdentifier()
        let timeZone = getTimeZoneOffset()
        let language = Locale.current.languageCode ?? "unknown"

        let deviceName = UIDevice.current.name
        let osVersion = UIDevice.current.systemVersion

        return DeviceFields(
            os: "IOS",
            osTimeZone: timeZone,
            osLanguage: language,
            deviceType: "mob",
            deviceModel: deviceModel,
            deviceName: deviceName,
            osVersion: osVersion
        )
    }

    /// Backwards-compatible completion-based API.
    ///
    /// - Parameter completion: A closure receiving device fields dictionary.
    @available(iOSApplicationExtension, unavailable)
    public static func getDeviceFields(completion: @escaping ([String: Any]) -> Void) {
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
    public static func deviceIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? "unknown"
            }
        }
    }

    /// Retrieves the time zone offset in the format "+hhmm" or "-hhmm".
    ///
    /// - Returns: A string representing the time zone offset in the specified format.
    public static func getTimeZoneOffset() -> String {
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
    public static func getTimeZone() -> Int16 {
        let seconds = TimeZone.current.secondsFromGMT()
        let minutes = seconds / 60
        let value = -minutes

        if value > Int(Int16.max) { return Int16.max }
        if value < Int(Int16.min) { return Int16.min }
        return Int16(value)
    }
}
