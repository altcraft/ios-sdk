//
//  ProfileDataManager.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import Altcraft


@MainActor
class ProfileDataManager: ObservableObject {
    @Published var profileData: ProfileData?
    @Published var error: String?

    func fetchProfileData(with event: Event) {
        switch event.eventCode {
        case 234:
            if let responseWithHttp = event.value?["response_with_http_code"] as? ResponseWithHttp,
               let profile = responseWithHttp.response?.profile {
                profileData = profile
            } else {
                error = "Invalid response or profile data"
            }

        case 424, 434:
            error = event.message

        default:
            break
        }
    }
}

@MainActor
// Global singleton for accessing the StatusManager
class GlobalProfileDataManager { static let shared = ProfileDataManager() }
