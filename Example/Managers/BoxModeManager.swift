//
//  BoxModeManager.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

@MainActor
class BoxModeManager: ObservableObject {@Published var mode: String = AppConstants.BoxModeName.events}

// Global singleton for accessing TokenManager
@MainActor
class GlobalBoxModeManager {static let shared = BoxModeManager()}


