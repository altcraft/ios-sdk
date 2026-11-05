//
//  ProfileDatabase.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Core Data stack of the Profile module.
///
/// The Profile module owns its own persistent container and store file; Core
/// only provides the storage mechanism.
internal let profileDatabase = CoreDataManager(
    modelName: ProfileConstants.CoreData.modelName,
    storeFileName: ProfileConstants.CoreData.storeFileName
)
