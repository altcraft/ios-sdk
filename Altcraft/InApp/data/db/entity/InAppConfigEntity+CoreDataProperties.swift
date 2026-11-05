//
//  InAppConfigEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias InAppConfigEntityCoreDataPropertiesSet = NSSet

extension InAppConfigEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<InAppConfigEntity> {
        return NSFetchRequest<InAppConfigEntity>(entityName: "InAppConfigEntity")
    }

    @NSManaged var inAppAutoRequest: Bool
    @NSManaged var placementsRequestInterval: Int64
    @NSManaged var maxPlacements: Int32
}
