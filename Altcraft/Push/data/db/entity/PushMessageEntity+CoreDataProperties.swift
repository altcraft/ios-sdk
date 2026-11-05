//
//  PushMessageEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias PushMessageEntityCoreDataPropertiesSet = NSSet

extension PushMessageEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<PushMessageEntity> {
        return NSFetchRequest<PushMessageEntity>(entityName: "PushMessageEntity")
    }

    @NSManaged var deliverySent: Bool
    @NSManaged var openSent: Bool
    @NSManaged var time: Int64
    @NSManaged var uid: String?

}
