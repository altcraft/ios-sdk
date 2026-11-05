//
//  ConfigurationEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias ConfigurationEntityCoreDataPropertiesSet = NSSet

extension ConfigurationEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<ConfigurationEntity> {
        return NSFetchRequest<ConfigurationEntity>(entityName: "ConfigurationEntity")
    }

    @NSManaged var appInfo: Data?
    @NSManaged var rToken: String?
    @NSManaged var url: String?
}
