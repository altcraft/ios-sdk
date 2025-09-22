//
//  DeeplinkManager.swift
//
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

final class DeeplinkManager {

    enum Target: Equatable {
        case mode(Int) // 1..4
    }

    private enum C {
        static let scheme = "apns"
        static let host   = "com.altcraft"

        // Supported routes only
        static let home    = "/home"
        static let example = "/example"
        static let logs    = "/logs"
        static let config  = "/config"
    }

    func manage(url: URL) -> Target? {
        guard url.scheme == C.scheme,
              url.host   == C.host
        else { return nil }

        switch url.path.lowercased() {
        case C.home:    return .mode(1)
        case C.example: return .mode(2)
        case C.logs:    return .mode(3)
        case C.config:  return .mode(4)
        default:        return nil
        }
    }
}

