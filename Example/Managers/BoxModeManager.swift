//
//  BoxModeManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore

/// Holds the active screen mode.
@MainActor
class BoxModeManager: ObservableObject {@Published var mode: String = AppConstants.BoxModeName.events}

// Global singleton for accessing TokenManager
/// Shared `BoxModeManager` singleton.
@MainActor
class GlobalBoxModeManager {static let shared = BoxModeManager()}
