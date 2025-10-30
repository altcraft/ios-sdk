//
//  PushEventEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData


extension PushEventEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PushEventEntity> {
        return NSFetchRequest<PushEventEntity>(entityName: "PushEventEntity")
    }

    @NSManaged public var maxRetryCount: Int16
    @NSManaged public var retryCount: Int16
    @NSManaged public var time: Int64
    @NSManaged public var type: String?
    @NSManaged public var uid: String?

}

extension PushEventEntity : Identifiable {

}
