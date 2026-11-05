//
//  AltcraftConfiguration.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Altcraft SDK configuration class.
///
/// This class is responsible for initializing parameters for the Altcraft SDK,
/// including the API URL, resource token authentication, optional application
/// metadata, and an optional flag controlling internal SDK logging. Optional
/// module configurations (push, in-app, profile, and target) are stored as
/// generic values and interpreted by their owning modules.
///
/// It can be constructed only via the nested `Builder` class (see below).
@objc(AltcraftConfiguration)
@objcMembers
public final class AltcraftConfiguration: NSObject, Sendable {

    private let apiUrl: String
    private let rToken: String?
    private let appInfo: AppInfo?
    private let enableLogging: Bool?
    private let moduleConfigurations: ModuleConfigBox

    private init(
        apiUrl: String,
        rToken: String?,
        appInfo: AppInfo?,
        enableLogging: Bool?,
        moduleConfigurations: ModuleConfigBox
    ) {
        self.apiUrl = apiUrl
        self.rToken = rToken
        self.appInfo = appInfo
        self.enableLogging = enableLogging
        self.moduleConfigurations = moduleConfigurations
        super.init()
    }

    /// Indicates whether the API URL is empty or blank.
    var apiUrlIsBlank: Bool {
        apiUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Indicates whether the resource token is a non-nil blank string.
    ///
    /// A `nil` resource token is a valid value: authentication can be
    /// performed through a JWT provider.
    var rTokenIsBlank: Bool {
        rToken?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
    }

    /// Indicates whether the configuration is valid.
    ///
    /// Mirrors Android `AltcraftConfiguration.valid`.
    var valid: Bool {
        !apiUrlIsBlank && !rTokenIsBlank
    }

    /// Emits the configuration setup error when the configuration is invalid.
    ///
    /// Only the most severe violation is emitted. Mirrors Android
    /// `AltcraftConfiguration.error()`.
    func error() {
        if apiUrlIsBlank {
            CoreLog.error(#function, error: CoreEvents.invalidUrlValue)
        } else if rTokenIsBlank {
            CoreLog.error(#function, error: CoreEvents.invalidRTokenValue)
        }
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
        private let apiUrl: String
        private var rToken: String?
        private var appInfo: AppInfo?
        private var appInfoObjC: AppInfoObjC?
        private var enableLogging: Bool?
        private var moduleConfigurations: [String: any ModuleConfiguration] = [:]

        /// Creates a new `Builder` for constructing an immutable
        /// `AltcraftConfiguration`.
        ///
        /// Mirrors Android `AltcraftConfiguration.Builder` — all core
        /// parameters (API URL, optional role token, application metadata,
        /// logging flag) are provided at construction time, and module
        /// configurations are chained through ``addModuleConfiguration(_:)``.
        ///
        /// ```swift
        /// let configuration = AltcraftConfiguration.Builder(
        ///     apiUrl: "https://api.example.com",
        ///     enableLogging: true,
        ///     appInfo: AppInfo(appVer: "1.0.0")
        /// )
        /// .pushConfig(icon: "icon_name")
        /// .inAppConfig(maxPlacements: 10)
        /// .build()
        /// ```
        ///
        /// - Parameters:
        ///   - apiUrl: Base URL of the Altcraft API.
        ///   - rToken: Optional static resource token for authentication.
        ///   - appInfo: Optional application metadata including app ID and version.
        ///   - enableLogging: Optional flag controlling internal SDK logging:
        ///     `true` to explicitly enable logging, `false` to explicitly disable it,
        ///     `nil` to keep the default SDK behavior.
        public init(
            apiUrl: String,
            rToken: String? = nil,
            appInfo: AppInfo? = nil,
            enableLogging: Bool? = nil
        ) {
            self.apiUrl = apiUrl
            self.rToken = rToken
            self.appInfo = appInfo
            self.enableLogging = enableLogging
            super.init()
        }

        /// Objective-C compatible initializer.
        ///
        /// - Parameters:
        ///   - apiUrl: Base URL of the Altcraft API.
        ///   - rToken: Static resource token for authentication, or `nil`.
        ///   - appInfoObjC: Objective-C DTO containing app metadata, or `nil`.
        ///   - enableLogging: Flag controlling internal SDK logging. Pass
        ///     `true` to enable logging, `false` to disable.
        @objc(initWithApiUrl:RToken:AppInfo:EnableLogging:)
        public init(
            apiUrl: String,
            rToken: String?,
            appInfoObjC: AppInfoObjC?,
            enableLogging: Bool
        ) {
            self.apiUrl = apiUrl
            self.rToken = rToken
            self.appInfoObjC = appInfoObjC
            self.enableLogging = enableLogging
            super.init()
        }

        /// Adds a configuration of an optional SDK module.
        ///
        /// The configuration is stored and returned as an immutable snapshot
        /// by ``build()``. An existing configuration of the same module is
        /// replaced.
        ///
        /// - Parameter configuration: Module configuration to add.
        /// - Returns: This builder for chaining.
        @nonobjc
        @discardableResult
        @_spi(_Altcraft) public func addModuleConfiguration(
            _ configuration: any ModuleConfiguration
        ) -> Builder {
            moduleConfigurations[configuration.moduleId] = configuration
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

        /// Builds and returns an `AltcraftConfiguration` instance.
        ///
        /// The builder does not reject invalid values (for example an empty or
        /// blank API URL). Validity is checked during SDK initialization in
        /// ``ConfigManager/setConfig(_:)``, which deletes the stored
        /// configuration and emits the setup error when the values are invalid.
        ///
        /// This method resolves application metadata
        /// (prefers Swift `AppInfo`, otherwise converts from `AppInfoObjC`).
        ///
        /// Push provider priority and in-app auto-request settings are owned by
        /// their modules through module configurations; core stores them without
        /// interpreting them.
        ///
        /// - Returns: The constructed `AltcraftConfiguration`.
        public func build() -> AltcraftConfiguration {
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
                enableLogging: enableLogging,
                moduleConfigurations: ModuleConfigBox(
                    moduleConfigurations
                )
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

    /// Returns the configuration of the specified optional module.
    ///
    /// - Parameter moduleId: Unique identifier of the module.
    /// - Returns: Module configuration, or `nil` if it is not provided.
    @nonobjc
    func getModuleConfiguration(
        _ moduleId: String
    ) -> (any ModuleConfiguration)? {
        moduleConfigurations.values[moduleId]
    }

    /// Returns a snapshot of all optional module configurations.
    ///
    /// - Returns: Module configurations indexed by module identifiers.
    @nonobjc
    func getModuleConfigurations()
        -> [String: any ModuleConfiguration] {
        moduleConfigurations.values
    }
}
