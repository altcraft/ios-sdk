//
//  MobileEventEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData


extension MobileEventEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MobileEventEntity> {
        return NSFetchRequest<MobileEventEntity>(entityName: "MobileEventEntity")
    }

    @NSManaged public var altcraftClientID: String?
    @NSManaged public var eventName: String?
    @NSManaged public var matching: Data?
    @NSManaged public var matchingType: String?
    @NSManaged public var maxRetryCount: Int16
    @NSManaged public var payload: Data?
    @NSManaged public var profileFields: Data?
    @NSManaged public var retryCount: Int16
    @NSManaged public var sendMessageId: String?
    @NSManaged public var sid: String?
    @NSManaged public var subscription: Data?
    @NSManaged public var time: Int64
    @NSManaged public var timeZone: Int16
    @NSManaged public var userTag: String?
    @NSManaged public var utmTags: Data?

}

extension MobileEventEntity : Identifiable {

}
