//
//  ProfileDataManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush
import AltcraftInApp
import AltcraftProfile
import AltcraftTarget

private typealias ProfileHttpResponse =
    ResponseModel.ResponseWithHttpCode<ResponseModel.ResponseWithProfile>

/// Manages profile data received from push status SDK events.
@MainActor
final class ProfileDataManager: ObservableObject {

    /// Latest received profile data.
    @Published var profileData: ProfileData?

    /// Latest profile loading error message.
    @Published var error: String?

    /// Updates profile data or error using an Altcraft SDK event.
    ///
    /// - Parameter event: SDK event containing push status response data.
    func fetchProfileData(with event: Event) {
        guard let sdkEvent = event.event,
              let push = sdkEvent as? PushModuleEvents else {
            return
        }

        switch push {
        case .pushStatusRequestSuccessful:
            guard
                let profile = event.value?["profile"] as? ProfileData
            else {
                error = "Invalid response or profile data"
                return
            }

            profileData = profile
            error = nil

        case .pushStatusRequestFailed:
            error = event.message

        default:
            break
        }
    }
}

/// Provides global access to profile data manager.
@MainActor
final class GlobalProfileDataManager {

    /// Shared profile data manager instance.
    static let shared = ProfileDataManager()

    private init() {}
}
