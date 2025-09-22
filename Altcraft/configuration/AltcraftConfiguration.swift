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
/// and an optional list of push notification providers in priority order.
public final class AltcraftConfiguration {
    
    private let apiUrl: String
    private let rToken: String?
    private var appInfo: AppInfo?
    private var providerPriorityList: [String]?
    
    private init(
        apiUrl: String,
        rToken: String?,
        appInfo: AppInfo?,
        providerPriorityList: [String]?
    ) {
        self.apiUrl = apiUrl
        self.rToken = rToken
        self.appInfo = appInfo
        self.providerPriorityList = providerPriorityList
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
    public class Builder {
        private var apiUrl: String?
        private var rToken: String?
        private var appInfo: AppInfo?
        private var providerPriorityList: [String]?
        
        public init() {}
        
        /// Sets the Altcraft API URL.
        public func setApiUrl(_ url: String) -> Builder {
            self.apiUrl = url
            return self
        }
        
        /// Sets the resource authentication token.
        public func setRToken(_ rToken: String?) -> Builder {
            self.rToken = rToken
            return self
        }
        
        /// Sets application metadata such as app ID and version.
        public func setAppInfo(_ info: AppInfo?) -> Builder {
            self.appInfo = info
            return self
        }
        
        /// Sets the priority order of push notification providers.
        public func setProviderPriorityList(_ list: [String]?) -> Builder {
            self.providerPriorityList = list
            return self
        }
        
        /// Builds and returns a validated AltcraftConfiguration instance, or nil if required values are missing.
        public func build() -> AltcraftConfiguration? {
            guard let apiUrl = apiUrl, !apiUrl.isEmpty else {
                errorEvent(#function, error: invalidUrlValue)
                return nil
            }

            if let list = providerPriorityList, !TokenManager.shared.allProvidersValid(list) {
                errorEvent(#function, error: invalidPushProviders)
                return nil
            }

            return AltcraftConfiguration(
                apiUrl: apiUrl,
                rToken: rToken,
                appInfo: appInfo,
                providerPriorityList: providerPriorityList
            )
        }
    }

    /// Returns the API endpoint URL.
    public func getApiUrl() -> String {
        return apiUrl
    }
    
    /// Returns the static resource token (if set).
    public func getRToken() -> String? {
        return rToken
    }

    /// Returns application metadata (if set).
    public func getAppInfo() -> AppInfo? {
        return appInfo
    }
    
    /// Returns the priority order of push notification providers (if set).
    public func getProviderPriorityList() -> [String]? {
        return providerPriorityList
    }
}

