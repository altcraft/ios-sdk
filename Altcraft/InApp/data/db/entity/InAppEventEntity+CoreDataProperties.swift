//
//  InAppEventEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias InAppEventEntityCoreDataPropertiesSet = NSSet

extension InAppEventEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<InAppEventEntity> {
        return NSFetchRequest<InAppEventEntity>(entityName: "InAppEventEntity")
    }

    @NSManaged var maxRetryCount: Int16
    @NSManaged var requestId: String?
    @NSManaged var retryCount: Int16
    @NSManaged var time: Int64
    @NSManaged var smid: String?
    @NSManaged var acid: String?
    @NSManaged var type: String?
    @NSManaged var data: Data?

}
