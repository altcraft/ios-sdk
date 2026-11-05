//
//  AltcraftObjCTypes.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

// MARK: - Configuration

/// Objective-C compatible DTO used to pass  Firebase analytics app metadata (app ID, install ID, version)
/// from Objective-C environments into the Swift SDK.
/// This class acts as a lightweight bridge between Objective-C and Swift models.
@objcMembers
public final class AppInfoObjC: NSObject {
    public let appID: String
    public let appIID: String
    public let appVer: String

    public init(appID: String, appIID: String, appVer: String) {
        self.appID = appID
        self.appIID = appIID
        self.appVer = appVer
        super.init()
    }
}

// MARK: - PublicPushSubscriptionFunctions

/// Objective-C–friendly representation of a subscription category.
///
/// Mirrors the Swift `CategoryData` type, but uses an `NSObject` subclass so
/// it can be consumed directly from Objective-C code.
///
/// ```objc
/// CategoryDataObjC *news = [[CategoryDataObjC alloc] initWithName:@"news"
///                                                           title:@"News"
///                                                          steady:YES
///                                                          active:YES];
/// ```
@objcMembers
public final class CategoryDataObjC: NSObject {
    public let name: String
    public let title: String
    public let steady: Bool
    public let active: Bool

    public init(name: String, title: String, steady: Bool, active: Bool) {
        self.name = name
        self.title = title
        self.steady = steady
        self.active = active
        super.init()
    }

    /// Swift -> ObjC factory. Returns `nil` if required fields are missing.
    /// Notes about defaults on Swift optional fields:
    /// - `name`: required (otherwise returns `nil`)
    /// - `title`: defaults to `""`
    /// - `steady`: defaults to `false`
    /// - `active`: defaults to `false`
    static func fromSwift(_ c: CategoryData) -> CategoryDataObjC? {
        guard let name = c.name else { return nil }
        let title = c.title ?? ""
        let steady = c.steady ?? false
        let active = c.active ?? false
        return CategoryDataObjC(name: name, title: title, steady: steady, active: active)
    }

    /// ObjC -> Swift converter for arrays of categories.
    /// Converts `[CategoryDataObjC]` into `[CategoryData]`.
    @_spi(_Altcraft) public static func toSwiftArray(_ arr: [CategoryDataObjC]?) -> [CategoryData]? {
        guard let arr, !arr.isEmpty else { return [] }
        return arr.map {
            CategoryData(
                name: $0.name,
                title: $0.title,
                steady: $0.steady,
                active: $0.active
            )
        }
    }
}

/// Objective-C–friendly wrapper for the Swift `ResponseWithHttpCode` struct.
/// Carries the HTTP code and a raw NSDictionary representation of the response
/// (if encoding is possible).
@objcMembers
public final class ResponseWithHttpCodeObjC: NSObject {
    public let httpCode: NSNumber?
    public let responseJSON: NSDictionary?

    public init(httpCode: NSNumber?, responseJSON: NSDictionary?) {
        self.httpCode = httpCode
        self.responseJSON = responseJSON
        super.init()
    }

    /// Factory from Swift `ResponseWithHttpCode<ResponseWithProfile>?`.
    ///
    /// Module-facing API: used by subscription flows in AltcraftPush /
    /// AltcraftInApp to bridge profile responses to ObjC.
    @_spi(_Altcraft) public static func from(
        _ s: ResponseModel.ResponseWithHttpCode<ResponseModel.ResponseWithProfile>?
    ) -> ResponseWithHttpCodeObjC? {
        guard let s else { return nil }
        let codeNum = s.httpCode.map { NSNumber(value: $0) }
        let json: NSDictionary?
        if let resp = s.response {
            json = (try? encodeResponseToNSDictionary(resp)) ?? nil
        } else {
            json = nil
        }
        return ResponseWithHttpCodeObjC(httpCode: codeNum, responseJSON: json)
    }
}

/// Helper: encode Swift `Codable` response to NSDictionary for Objective-C callers.
private func encodeResponseToNSDictionary<T: Encodable>(_ response: T) throws -> NSDictionary {
    let data = try JSONEncoder().encode(response)
    let obj = try JSONSerialization.jsonObject(with: data, options: [])
    return obj as? NSDictionary ?? [:]
}
