//
//  SubscribeEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData


extension SubscribeEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SubscribeEntity> {
        return NSFetchRequest<SubscribeEntity>(entityName: "SubscribeEntity")
    }

    @NSManaged public var cats: Data?
    @NSManaged public var customFields: Data?
    @NSManaged public var maxRetryCount: Int16
    @NSManaged public var profileFields: Data?
    @NSManaged public var replace: Bool
    @NSManaged public var retryCount: Int16
    @NSManaged public var skipTriggers: Bool
    @NSManaged public var status: String?
    @NSManaged public var sync: Int16
    @NSManaged public var time: Int64
    @NSManaged public var uid: String?
    @NSManaged public var userTag: String?

}

extension SubscribeEntity : Identifiable {

}
