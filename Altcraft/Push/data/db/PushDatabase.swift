//
//  PushDatabase.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Core Data stack of the Push module.
///
/// The Push module owns its own persistent container and store file; Core only
/// provides the storage mechanism.
internal let pushDatabase = CoreDataManager(
    modelName: PushConstants.CoreData.modelName,
    storeFileName: PushConstants.CoreData.storeFileName
)
