//
//  ResponseModel.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

public typealias ProfileHttpResponse =
ResponseModel.ResponseWithHttpCode<
    ResponseModel.ResponseWithProfile
>

/// Contains parsed server response models used by the SDK.
public enum ResponseModel {
    public static let errorKey = "error"
    public static let errorTextKey = "error_text"
    public static let profileKey = "profile"

    /// Base marker protocol for all parsed server response models.
    public protocol ResponseData {
        /// Additional data used as SDK event value payload.
        var eventData: [String: Any?] { get }

        /// Additional data used as SDK log payload.
        var logData: [String: Any?]? { get }
    }

    /// Base contract for API responses that may contain error information returned by the server.
    ///
    /// - Properties:
    ///   - error: Optional numeric error code.
    ///   - errorText: Optional error description.
    public protocol BaseResponseData: ResponseData {
        var error: Int? { get }
        var errorText: String? { get }
    }

    /// Wraps the API response together with the HTTP status code.
    ///
    /// - Properties:
    ///   - httpCode: The HTTP status code returned by the server, for example `200` or `404`.
    ///   - response: The parsed API response body, or `nil` if unavailable.
    public struct ResponseWithHttpCode<T: ResponseData & Sendable>: Sendable {
        public let httpCode: Int?
        public let response: T?

        public init(httpCode: Int?, response: T?) {
            self.httpCode = httpCode
            self.response = response
        }
    }

    /// Represents a basic server response without additional payload data.
    ///
    /// - Properties:
    ///   - error: Optional numeric error code returned by the server.
    ///   - errorText: Error description, if available.
    public struct AsyncResponse: Codable, BaseResponseData, Sendable {
        public let error: Int?
        public let errorText: String?

        /// JSON coding keys for the parent model.
        public enum CodingKeys: String, CodingKey {
            case error
            case errorText = "error_text"
        }

        public init(error: Int? = nil, errorText: String? = nil) {
            self.error = error
            self.errorText = errorText
        }
    }

    /// Response containing authorization data returned by the server.
    ///
    /// - Properties:
    ///   - error: Optional numeric error code returned by the server.
    ///   - errorText: Error description, if available.
    ///   - acid: Altcraft identifier returned by the server.
    ///   - isTest: Indicates whether the profile is a test profile.
    public struct ResponseWithAuth: Codable, BaseResponseData, Sendable {
        public let error: Int?
        public let errorText: String?
        public let acid: String?
        public let isTest: Bool

        /// JSON coding keys for the parent model.
        public enum CodingKeys: String, CodingKey {
            case error
            case errorText = "error_text"
            case acid
            case isTest = "is_test"
        }

        public init(
            error: Int? = nil,
            errorText: String? = nil,
            acid: String? = nil,
            isTest: Bool = false
        ) {
            self.error = error
            self.errorText = errorText
            self.acid = acid
            self.isTest = isTest
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(
                keyedBy: CodingKeys.self
            )

            self.error = try container.decodeIfPresent(Int.self, forKey: .error)
            self.errorText = try container.decodeIfPresent(String.self, forKey: .errorText)
            self.acid = try container.decodeIfPresent(String.self, forKey: .acid)
            self.isTest = try container.decodeIfPresent(Bool.self, forKey: .isTest) ?? false
        }
    }

    /// Represents a server response containing profile data from the Altcraft platform.
    ///
    /// - Properties:
    ///   - error: Optional numeric error code returned by the server.
    ///   - errorText: Error description, if available.
    ///   - profile: Profile data in the Altcraft platform.
    public struct ResponseWithProfile: Codable, BaseResponseData, Sendable {
        public let error: Int?
        public let errorText: String?
        public let profile: ProfileData?

        /// JSON coding keys for the parent model.
        public enum CodingKeys: String, CodingKey {
            case error
            case errorText = "error_text"
            case profile
        }

        public var eventData: [String: Any?] {
            [
                ResponseModel.errorKey: error,
                ResponseModel.errorTextKey: errorText,
                ResponseModel.profileKey: profile
            ]
        }

        public init(
            error: Int? = nil,
            errorText: String? = nil,
            profile: ProfileData? = nil
        ) {
            self.error = error
            self.errorText = errorText
            self.profile = profile
        }
    }

    /// Ordered key-value list that preserves insertion order.
    ///
    /// Swift `[String: Any]` does not preserve insertion order. This type
    /// mirrors Android `LinkedHashMap` so that logs can output keys in a
    /// deterministic order (request fields first, then response fields,
    /// then `http_code`), matching Android's log format.
    public struct OrderedLogValue {
        public let entries: [(key: String, value: Any?)]

        public init(_ entries: [(key: String, value: Any?)]) {
            self.entries = entries
        }

        /// Convenience initializer that converts a dictionary to an ordered
        /// entry list. Keys are sorted alphabetically for deterministic
        /// output (Swift dictionaries do not preserve insertion order).
        public init(_ dictionary: [String: Any?]) {
            self.entries = dictionary
                .filter { $0.value != nil }
                .sorted { $0.key < $1.key }
                .map { (key: $0.key, value: $0.value) }
        }

        /// Converts to a plain dictionary representation.
        public var dictionary: [String: Any?] {
            var result: [String: Any?] = [:]
            for (key, value) in entries {
                result[key] = value
            }
            return result
        }
    }

    /// Holds additional payload data for SDK event reporting and logging.
    ///
    /// - Properties:
    ///   - eventValue: Additional data used as SDK event value payload.
    ///   - logValue: Additional data used as SDK log payload (ordered,
    ///     preserving request-first then response, then http_code insertion
    ///     order to match Android `MapBuilder.createEventValue`).
    struct ResponseEventValue {
        let eventValue: [String: Any?]?
        let logValue: OrderedLogValue
    }

    /// Holds processed response data together with SDK event context.
    ///
    /// - Properties:
    ///   - status: Resulting response status.
    ///   - responseData: Parsed response body, or `nil` if unavailable.
    ///   - httpCode: HTTP status code returned by the server.
    ///   - value: Additional event and log payload associated with the response.
    ///   - errorEvent: SDK event used when the request fails.
    ///   - successEvent: SDK event used when the request succeeds.
    struct ResponseResult<T: ResponseData> {
        let status: ResponseProcessor.ResponseStatus
        let responseData: T?
        let httpCode: Int?
        let value: ResponseEventValue
        let errorEvent: any SDKEvent
        let successEvent: any SDKEvent
    }
}

/// Default event and log payload for responses containing server error information.
public extension ResponseModel.BaseResponseData {
    var eventData: [String: Any?] {
        [
            ResponseModel.errorKey: error,
            ResponseModel.errorTextKey: errorText
        ]
    }

    var logData: [String: Any?]? {
        [
            ResponseModel.errorKey: error,
            ResponseModel.errorTextKey: errorText
        ]
    }
}
