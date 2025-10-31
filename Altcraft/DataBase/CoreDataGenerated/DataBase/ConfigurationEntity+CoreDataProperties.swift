//
//  ConfigurationEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData


extension ConfigurationEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ConfigurationEntity> {
        return NSFetchRequest<ConfigurationEntity>(entityName: "ConfigurationEntity")
    }

    @NSManaged public var appInfo: Data?
    @NSManaged public var providerPriorityList: Data?
    @NSManaged public var rToken: String?
    @NSManaged public var url: String?

}

extension ConfigurationEntity : Identifiable {}
