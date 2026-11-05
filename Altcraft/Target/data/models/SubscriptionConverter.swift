//
//  SubscriptionConverter.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Error for unsupported subscription types.
enum SubscriptionConverterError: LocalizedError {
    case unsupportedSubscriptionType
    var errorDescription: String? {
        switch self {
        case .unsupportedSubscriptionType:
            return "unsupported subscription type. Available: EmailSubscription, SmsSubscription, PushSubscription, CcDataSubscription"
        }
    }
}

/// Encodes a polymorphic `Subscription` into JSON `Data`.
///
/// Supports: `EmailSubscription`, `SmsSubscription`, `PushSubscription`, `CcDataSubscription`.
/// - Parameter sub: Subscription value to encode.
/// - Returns: JSON `Data` on success, otherwise `nil` (logs the error).
func encodeSubscription(_ sub: (any Subscription)?) -> Data? {
    guard let sub else { return nil }
    let encoder = JSONEncoder()
    do {
        switch sub {
        case let s as EmailSubscription:
            return try encoder.encode(s)
        case let s as SmsSubscription:
            return try encoder.encode(s)
        case let s as PushSubscription:
            return try encoder.encode(s)
        case let s as CcDataSubscription:
            return try encoder.encode(s)
        default:
            TargetLog.error(#function, error: SubscriptionConverterError.unsupportedSubscriptionType)
            return nil
        }
    } catch {
        TargetLog.error(#function, error: error)
        return nil
    }
}

/// Decodes a polymorphic `Subscription` from JSON `Data`.
/// Tries known concrete types in order; returns `nil` if no type matches.
func decodeSubscription(from data: Data?) -> (any Subscription)? {
    guard let data else { return nil }
    let decoder = JSONDecoder()
    if let v = try? decoder.decode(SmsSubscription.self, from: data) { return v }
    if let v = try? decoder.decode(PushSubscription.self, from: data) { return v }
    if let v = try? decoder.decode(EmailSubscription.self, from: data) { return v }
    if let v = try? decoder.decode(CcDataSubscription.self, from: data) { return v }
    TargetLog.error(#function, error: SubscriptionConverterError.unsupportedSubscriptionType)
    return nil
}

/// Encodes a `UTM` value into JSON data.
///
/// Use this to serialize UTM parameters before storing them or sending in a request.
/// - Parameter utm: The `UTM` value to encode. If `nil`, returns `nil`.
/// - Returns: JSON `Data` on success; `nil` if `utm` is `nil` or encoding fails (the error is logged).
func encodeUTM(_ utm: UTM?) -> Data? {
    guard let utm else { return nil }
    do {
        return try JSONEncoder().encode(utm)
    } catch {
        TargetLog.error(#function, error: error)
        return nil
    }
}

/// Decodes a `UTM` value from JSON data.
///
/// Use this to reconstruct UTM parameters previously produced by `encodeUTM(_:)`
/// or received from an external source.
/// - Parameter data: JSON `Data` representing a `UTM` object.
/// - Returns: A `UTM` instance on success; `nil` if `data` is `nil` or decoding fails (the error is logged).
func decodeUTM(_ data: Data?) -> UTM? {
    guard let data else { return nil }
    do {
        return try JSONDecoder().decode(UTM.self, from: data)
    } catch {
        TargetLog.error(#function, error: error)
        return nil
    }
}
