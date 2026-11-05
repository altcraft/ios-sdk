//
//  PushEventEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias PushEventEntityCoreDataPropertiesSet = NSSet

extension PushEventEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<PushEventEntity> {
        return NSFetchRequest<PushEventEntity>(entityName: "PushEventEntity")
    }

    @NSManaged var maxRetryCount: Int16
    @NSManaged var requestId: String?
    @NSManaged var retryCount: Int16
    @NSManaged var time: Int64
    @NSManaged var type: String?
    @NSManaged var uid: String?

}
