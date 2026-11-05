//
//  InAppsEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias InAppsEntityCoreDataPropertiesSet = NSSet

extension InAppsEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<InAppsEntity> {
        return NSFetchRequest<InAppsEntity>(entityName: "InAppsEntity")
    }

    @NSManaged var acid: String?
    @NSManaged var deviceId: String?
    @NSManaged var lastPublish: Int64
    @NSManaged var placementRulesChecksum: String?
    @NSManaged var lastRequestTime: Int64
}
