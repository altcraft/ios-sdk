//
//  InAppDatabase.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Core Data stack of the InApp module.
///
/// The InApp module owns its own persistent container and store file; Core only
/// provides the storage mechanism.
internal let inAppDatabase = CoreDataManager(
    modelName: InAppConstants.CoreData.modelName,
    storeFileName: InAppConstants.CoreData.storeFileName
)
