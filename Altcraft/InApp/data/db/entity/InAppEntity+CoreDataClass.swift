//
//  InAppEntity+CoreDataClass.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

typealias InAppEntityCoreDataClassSet = NSSet

/// Core Data entity storing in-app campaigns.
@objc(InAppEntity)
class InAppEntity: NSManagedObject {

}
