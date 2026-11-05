//
//  AltcraftExports.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_exported import AltcraftCore
#endif

#if canImport(AltcraftPush)
@_exported import AltcraftPush
#endif

#if canImport(AltcraftProfile)
@_exported import AltcraftProfile
#endif

#if canImport(AltcraftInApp)
@_exported import AltcraftInApp
#endif

#if canImport(AltcraftTarget)
@_exported import AltcraftTarget
#endif
