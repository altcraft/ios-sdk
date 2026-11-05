//
//  TargetEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias TargetEntityCoreDataPropertiesSet = NSSet

extension TargetEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<TargetEntity> {
        return NSFetchRequest<TargetEntity>(entityName: "TargetEntity")
    }

    @NSManaged var altcraftClientID: String?
    @NSManaged var eventName: String?
    @NSManaged var matching: Data?
    @NSManaged var matchingType: String?
    @NSManaged var maxRetryCount: Int16
    @NSManaged var payload: Data?
    @NSManaged var profileFields: Data?
    @NSManaged var requestId: String?
    @NSManaged var retryCount: Int16
    @NSManaged var sendMessageId: String?
    @NSManaged var sid: String?
    @NSManaged var subscription: Data?
    @NSManaged var time: Int64
    @NSManaged var timeZone: Int16
    @NSManaged var userTag: String?
    @NSManaged var utmTags: Data?

}
