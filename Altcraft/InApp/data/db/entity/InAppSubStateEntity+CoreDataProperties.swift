//
//  InAppSubStateEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias InAppSubStateEntityCoreDataPropertiesSet = NSSet

extension InAppSubStateEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<InAppSubStateEntity> {
        return NSFetchRequest<InAppSubStateEntity>(entityName: "InAppSubStateEntity")
    }

    @NSManaged var status: String?
    @NSManaged var userTag: String?

}
