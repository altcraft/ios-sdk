//
//  Converter.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

///// Parses a JSON response into a `Response` object.
/////
///// - Parameter data: The JSON data received from the API.
///// - Returns: A `Response` object if parsing is successful, otherwise `nil`.
//func parseResponse(data: Data?) -> Response? {
//    try? data.flatMap { try JSONDecoder().decode(Response.self, from: $0) }
//}

/// Decodes an `AppInfo` object from a given `Data?`.
/// - Parameter data: The `Data?` object to decode into an `AppInfo`.
/// - Returns: The decoded `AppInfo` object, or `nil` if decoding fails.
func decodeAppInfo(from data: Data?) -> AppInfo? {
    guard let data = data else { return nil }
    do {
        return try JSONDecoder().decode(AppInfo.self, from: data)
    } catch {
        CoreLog.error(#function, error: error)
        return nil
    }
}

/// Encodes an `AppInfo` object into `Data?`.
/// - Parameter appInfo: The `AppInfo?` object to encode into `Data`.
/// - Returns: The encoded `Data`, or `nil` if encoding fails.
func encodeAppInfo(_ appInfo: AppInfo?) -> Data? {
    guard let appInfo = appInfo else { return nil }
    do {
        return try JSONEncoder().encode(appInfo)
    } catch {
        CoreLog.error(#function, error: error)
        return nil
    }
}

/// Decodes a provider priority list from a given `Data?`.
/// - Parameter data: The `Data?` object to decode into an array of strings.
/// - Returns: The decoded priority list, or `nil` if decoding fails.
@_spi(_Altcraft) public func decodeList(from data: Data?) -> [String]? {
    guard let data = data else { return nil }
    do {
        return try JSONDecoder().decode([String].self, from: data)
    } catch {
        CoreLog.error(#function, error: error)
        return nil
    }
}

/// Encodes a provider priority list into `Data?`.
/// - Parameter list: The priority list to encode into `Data`.
/// - Returns: The encoded `Data`, or `nil` if encoding fails.
@_spi(_Altcraft) public func encodeList(_ list: [String]?) -> Data? {
    guard let list = list else { return nil }
    do {
        return try JSONEncoder().encode(list)
    } catch {
        CoreLog.error(#function, error: error)
        return nil
    }
}

/// Encodes an array of `CategoryData` into `Data?`.
///
/// - Parameter cats: The optional array of `CategoryData` to encode.
/// - Returns: A `Data` object if encoding succeeds, or `nil` on failure.
@_spi(_Altcraft) public func encodeCats(_ cats: [CategoryData]?) -> Data? {
    guard let cats = cats else { return nil }
    do {
        return try JSONEncoder().encode(cats)
    } catch {
        CoreLog.error(#function, error: error)
        return nil
    }
}

/// Decodes a JSON-encoded `Data` object into an array of `CategoryData`.
///
/// - Parameter data: The optional `Data` to decode.
/// - Returns: An array of `CategoryData`, or `nil` on failure.
@_spi(_Altcraft) public func decodeCats(_ data: Data?) -> [CategoryData]? {
    guard let data = data else { return nil }
    do {
        return try JSONDecoder().decode([CategoryData].self, from: data)
    } catch {
        CoreLog.error(#function, error: error)
        return nil
    }
}

/// Decodes a `Data?` object into a JSON dictionary (`[String: Any]?`).
/// - Parameter data: The `Data?` object to decode into a dictionary.
/// - Returns: The decoded dictionary, or `nil` if decoding fails.
@_spi(_Altcraft) public func decodeAnyMap(_ data: Data?) -> [String: Any]? {
    guard let data = data else { return nil }
    do {
        return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    } catch {
        CoreLog.error(#function, error: error)
        return nil
    }
}

/// Serializes a `[String: Any?]` dictionary into `Data?`.
/// - Parameter map: The dictionary to serialize.
/// - Returns: A `Data?` object representing the serialized dictionary, or `nil` if serialization fails.
@_spi(_Altcraft) public func encodeAnyMap(_ map: [String: Any?]?) -> Data? {
    guard let map = map else { return nil }

    let filteredFields = map.compactMapValues { $0 }

    guard JSONSerialization.isValidJSONObject(filteredFields) else {
        CoreLog.error(#function, error: CoreEvents.nonJsonObject)
        return nil
    }
    do {
        return try JSONSerialization.data(withJSONObject: filteredFields, options: [])
    } catch {
        CoreLog.error(#function, error: error)
        return nil
    }
}

/// Encodes an optional value into JSON data.
///
/// - Parameter value: Encodable value.
/// - Returns: JSON data, or `nil` if value is `nil`.
 public func encodeInAppValue<T: Encodable>(
    _ value: T?
) throws -> Data? {
    guard let value else { return nil }
    return try JSONEncoder().encode(value)
}

/// Decodes an optional JSON data value.
///
/// - Parameters:
///   - type: Expected decoded type.
///   - data: JSON data.
/// - Returns: Decoded value, or `nil` if data is `nil`.
 public func decodeInAppValue<T: Decodable>(
    _ type: T.Type,
    from data: Data?
) throws -> T? {
    guard let data else { return nil }
    return try JSONDecoder().decode(T.self, from: data)
}

/// Creates a `Configuration` instance from a `ConfigurationEntity` object.
///
/// - Parameters:
///   - configuration: The `ConfigurationEntity` to convert.
/// - Returns: A `Configuration` instance if valid, or `nil` if invalid (e.g., empty URL).
func configFromEntity(
    configuration: ConfigurationEntity
) -> Configuration? {
    guard let url = configuration.url, !url.isEmpty else {
        return nil
    }

    let appInfo = decodeAppInfo(
        from: configuration.appInfo
    )

    return Configuration(
        apiUrl: url,
        rToken: configuration.rToken,
        appInfo: appInfo
    )
}

