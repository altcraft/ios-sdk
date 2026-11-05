//
//  PushConfigEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias PushConfigEntityCoreDataPropertiesSet = NSSet

extension PushConfigEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<PushConfigEntity> {
        return NSFetchRequest<PushConfigEntity>(entityName: "PushConfigEntity")
    }

    @NSManaged var providerPriority: Data?
}
