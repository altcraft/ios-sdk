//
//  TargetDatabase.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Core Data stack of the Target module.
///
/// The Target module owns its own persistent container and store file; Core
/// only provides the storage mechanism.
internal let targetDatabase = CoreDataManager(
    modelName: TargetConstants.CoreData.modelName,
    storeFileName: TargetConstants.CoreData.storeFileName
)
