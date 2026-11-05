//
//  Structures.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

// MARK: - Internal Structs

/// Altcraft SDK configuration.
///
/// Holds base parameters required to build requests and drive SDK behavior.
struct Configuration: Sendable {
    /// Base API URL.
    let apiUrl: String

    /// Resource token (optional).
    let rToken: String?

    /// Application metadata (optional).
    let appInfo: AppInfo?
}

/// JWT authentication payload.
///
/// Used when requests require JWT + a SHA-256 hash of a normalized matching claim.
struct JWTData {
    /// JWT token.
    let jwt: String
    /// SHA-256 hash of the normalized matching claim.
    let hash: String
    /// Matching method (e.g., `"push_sub"`).
    let matching: String
}

/// Sendable representation of device fields.
struct DeviceFields: Sendable {
    let os: String
    let osTimeZone: String
    let osLanguage: String
    let deviceType: String
    let deviceModel: String
    let deviceName: String
    let osVersion: String

    /// Flattens the device metadata into a request-payload dictionary.
    ///
    /// - Returns: A dictionary with `_os`, `_os_tz`, `_os_language`,
    ///   `_device_type`, `_device_model`, `_device_name` and `_os_ver` keys.
    func asDictionary() -> [String: Any] {
        [
            "_os": os,
            "_os_tz": osTimeZone,
            "_os_language": osLanguage,
            "_device_type": deviceType,
            "_device_model": deviceModel,
            "_device_name": deviceName,
            "_os_ver": osVersion
        ]
    }
}

// MARK: - Public Structs

/// Application metadata used for analytics.
///
/// Provides basic app identifiers attached to events for tracking and reporting.
public struct AppInfo: Codable, Sendable {
    /// Unique application identifier.
    public var appID: String

    /// Installation identifier for this specific app instance.
    public var appIID: String

    /// Application version string.
    public var appVer: String

    /// Creates a new `AppInfo`.
    ///
    /// All fields default to an empty string, matching Android `AppInfo`
    /// semantics so that callers can provide only the fields they care about,
    /// e.g. `AppInfo(appVer: "v1.0.0")`.
    ///
    /// - Parameters:
    ///   - appID: Application identifier.
    ///   - appIID: Installation identifier.
    ///   - appVer: Application version.
    public init(
        appID: String = "",
        appIID: String = "",
        appVer: String = ""
    ) {
        self.appID = appID
        self.appIID = appIID
        self.appVer = appVer
    }

    /// Converts `AppInfo` into a string map suitable for analytics fields.
    ///
    /// - Returns: A dictionary with `_app_id`, `_app_iid`, and `_app_ver`.
    func toAppFieldsMap() -> [String: String] {
        return [
            "_app_id": appID,
            "_app_iid": appIID,
            "_app_ver": appVer
        ]
    }
}

/// A type-safe representation of any JSON value.
///
/// Supports strings, numbers, booleans, objects, arrays, and null.
public enum JSONValue: Codable, CustomStringConvertible, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let num = try? container.decode(Double.self) {
            self = .number(num)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let obj = try? container.decode([String: JSONValue].self) {
            self = .object(obj)
        } else if let arr = try? container.decode([JSONValue].self) {
            self = .array(arr)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON type"
            )
        }
    }

    /// Encodes the JSON value into a single-value container.
    ///
    /// - Parameter encoder: Encoder receiving the value.
    /// - Throws: Encoding errors propagated from the container.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value):   try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value):  try container.encode(value)
        case .null:              try container.encodeNil()
        }
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .string(let value): return value
        case .number(let value): return String(value)
        case .bool(let value):   return String(value)
        case .object(let value): return value.mapValues { $0.description }.description
        case .array(let value):  return value.map { $0.description }.description
        case .null:              return "null"
        }
    }

    // MARK: - Convenience accessors

    /// Returns the underlying string when the value is `.string`.
    public var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    /// Returns the underlying number when the value is `.number`.
    public var numberValue: Double? {
        if case let .number(value) = self { return value }
        return nil
    }

    /// Returns the underlying boolean when the value is `.bool`.
    public var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    /// Returns the underlying object when the value is `.object`.
    public var objectValue: [String: JSONValue]? {
        if case let .object(value) = self { return value }
        return nil
    }

    /// Returns the underlying array when the value is `.array`.
    public var arrayValue: [JSONValue]? {
        if case let .array(value) = self { return value }
        return nil
    }
}

