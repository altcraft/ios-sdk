//
//  PushSubscribeEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias PushSubscribeEntityCoreDataPropertiesSet = NSSet

extension PushSubscribeEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<PushSubscribeEntity> {
        return NSFetchRequest<PushSubscribeEntity>(entityName: "PushSubscribeEntity")
    }

    @NSManaged var cats: Data?
    @NSManaged var customFields: Data?
    @NSManaged var maxRetryCount: Int16
    @NSManaged var profileFields: Data?
    @NSManaged var replace: Bool
    @NSManaged var requestId: String?
    @NSManaged var retryCount: Int16
    @NSManaged var skipTriggers: Bool
    @NSManaged var status: String?
    @NSManaged var sync: Bool
    @NSManaged var time: Int64
    @NSManaged var userTag: String?

}
