//
//  InAppStaticEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias InAppStaticEntityCoreDataPropertiesSet = NSSet

extension InAppStaticEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<InAppStaticEntity> {
        return NSFetchRequest<InAppStaticEntity>(entityName: "InAppStaticEntity")
    }

    @NSManaged var inAppLibraryJs: String?
    @NSManaged var blockJs: String?
    @NSManaged var blockCss: String?
    @NSManaged var createdAt: Int64

}
