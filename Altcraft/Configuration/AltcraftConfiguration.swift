//
//  AltcraftConfiguration.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Altcraft SDK configuration class.
///
/// This class is responsible for initializing parameters for the Altcraft SDK,
/// including the API URL, resource token authentication, optional application metadata,
/// an optional list of push notification providers in priority order,
/// and an optional flag controlling internal SDK logging.
///
/// It can be constructed only via the nested `Builder` class (see below).
@objc(AltcraftConfiguration)
@objcMembers
public final class AltcraftConfiguration: NSObject, Sendable{

    private let apiUrl: String
    private let rToken: String?
    private let appInfo: AppInfo?
    private let providerPriorityList: [String]?
    private let enableLogging: Bool?

    private init(
        apiUrl: String,
        rToken: String?,
        appInfo: AppInfo?,
        providerPriorityList: [String]?,
        enableLogging: Bool?
    ) {
        self.apiUrl = apiUrl
        self.rToken = rToken
        self.appInfo = appInfo
        self.providerPriorityList = providerPriorityList
        self.enableLogging = enableLogging
        super.init()
    }

    /// Builder for constructing an instance of AltcraftConfiguration.
    ///
    /// This builder allows configuring the SDK with required and optional parameters
    /// before building the final immutable configuration object.
    ///
    /// - Parameters:
    ///   - apiUrl: Base URL of the Altcraft API.
    ///   - rToken: Optional static resource token for authentication.
    ///   - appInfo: Optional application metadata including app ID and version.
    ///   - providerPriorityList: A list of provider names in priority order for push notifications.
    ///   - enableLogging: Optional flag controlling internal SDK logging:
    ///     `true` to explicitly enable logging, `false` to explicitly disable it,
    ///     `nil` to keep the default SDK behavior.
    ///
    /// ### Objective-C compatibility note:
    /// The Builder class is explicitly exposed to Objective-C under the name
    /// `AltcraftConfiguration_Builder`, so existing Objective-C code can call:
    /// `AltcraftConfiguration_Builder *builder = [AltcraftConfiguration_Builder new];`
    @objc(AltcraftConfiguration_Builder)
    @objcMembers
    public final class Builder: NSObject {

        private var apiUrl: String?
        private var rToken: String?
        private var appInfo: AppInfo?
        private var appInfoObjC: AppInfoObjC?
        private var providerPriorityList: [String]?
        private var enableLogging: Bool?

        public override init() {
            super.init()
        }

        /// Sets the Altcraft API URL.
        ///
        /// - Parameter url: Base endpoint of the Altcraft API.
        /// - Returns: Builder instance for chaining.
        @discardableResult
        public func setApiUrl(_ url: String) -> Builder {
            self.apiUrl = url
            return self
        }

        /// Sets the resource authentication token.
        ///
        /// - Parameter rToken: Optional token string used to authenticate resource requests.
        /// - Returns: Builder instance for chaining.
        @discardableResult
        public func setRToken(_ rToken: String?) -> Builder {
            self.rToken = rToken
            return self
        }

        /// Sets application metadata such as app ID and version (Swift `AppInfo` model).
        ///
        /// - Parameter info: Optional Swift app metadata object.
        /// - Returns: Builder instance for chaining.
        @discardableResult
        public func setAppInfo(_ info: AppInfo?) -> Builder {
            self.appInfo = info
            return self
        }

        /// Sets application metadata via Objective-C DTO (`AppInfoObjC`).
        ///
        /// Internally, this will be automatically converted into a Swift `AppInfo`
        /// during the `build()` call.
        ///
        /// - Parameter dto: Objective-C compatible DTO containing app metadata.
        /// - Returns: Builder instance for chaining.
        @available(swift, obsoleted: 1)
        @objc(setAppInfo:)
        @discardableResult
        public func setAppInfo(_ dto: AppInfoObjC?) -> Builder {
            self.appInfoObjC = dto
            return self
        }

        /// Sets the priority order of push notification providers.
        ///
        /// - Parameter list: Optional array of provider identifiers (`"ios-apns"`, `"ios-firebase"`, etc.)
        ///   defining the order in which the SDK should attempt push registration.
        /// - Returns: Builder instance for chaining.
        @discardableResult
        public func setProviderPriorityList(_ list: [String]?) -> Builder {
            self.providerPriorityList = list
            return self
        }

        /// Sets the internal SDK logging behavior.
        ///
        /// Use this flag to control Altcraft SDK logging:
        /// - `true`  → enable SDK logging.
        /// - `false` → disable SDK logging.
        /// - `nil`   → leave logging in its default mode (SDK decides).
        ///
        /// - Parameter enabled: Optional logging flag.
        /// - Returns: Builder instance for chaining.
        @discardableResult
        public func setEnableLogging(_ enabled: Bool?) -> Builder {
            self.enableLogging = enabled
            return self
        }

        /// Builds and returns a validated AltcraftConfiguration instance,
        /// or `nil` if required values are missing or invalid.
        ///
        /// This method performs several validation steps:
        /// 1. Checks that the API URL is provided.
        /// 2. Validates the push provider priority list (if set).
        /// 3. Resolves application metadata (prefers Swift `AppInfo`, otherwise converts from `AppInfoObjC`).
        ///
        /// - Returns: A valid `AltcraftConfiguration` or `nil` on validation failure.
        public func build() -> AltcraftConfiguration? {
            guard let apiUrl = apiUrl, !apiUrl.isEmpty else {
                errorEvent(#function, error: invalidUrlValue)
                return nil
            }
            if let list = providerPriorityList,
                !TokenManager.shared.allProvidersValid(list) {
                errorEvent(#function, error: invalidPushProviders)
                return nil
            }

            let resolvedAppInfo: AppInfo? = {
                if let swiftInfo = self.appInfo {
                    return swiftInfo
                }
                if let dto = self.appInfoObjC {
                    return AppInfo(
                        appID: dto.appID,
                        appIID: dto.appIID,
                        appVer: dto.appVer
                    )
                }
                return nil
            }()

            return AltcraftConfiguration(
                apiUrl: apiUrl,
                rToken: rToken,
                appInfo: resolvedAppInfo,
                providerPriorityList: providerPriorityList,
                enableLogging: enableLogging
            )
        }
    }

    /// Returns the API endpoint URL.
    public func getApiUrl() -> String {
        apiUrl
    }

    /// Returns the static resource token (if set).
    public func getRToken() -> String? {
        rToken
    }

    /// Returns application metadata (if set).
    public func getAppInfo() -> AppInfo? {
        appInfo
    }
    
    /// Returns the internal logging flag, if configured.
    public func getEnableLogging() -> Bool? {
        enableLogging
    }

    /// Returns the priority order of push notification providers (if set).
    public func getProviderPriorityList() -> [String]? {
        providerPriorityList
    }
}

