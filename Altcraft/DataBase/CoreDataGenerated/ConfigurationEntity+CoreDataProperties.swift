//
//  ConfigurationEntity+CoreDataProperties.swift
//  
//
//  Created by andrey on 03.03.2026.
//
//

public import Foundation
public import CoreData


public typealias ConfigurationEntityCoreDataPropertiesSet = NSSet

extension ConfigurationEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ConfigurationEntity> {
        return NSFetchRequest<ConfigurationEntity>(entityName: "ConfigurationEntity")
    }

    @NSManaged public var appInfo: Data?
    @NSManaged public var providerPriorityList: Data?
    @NSManaged public var rToken: String?
    @NSManaged public var url: String?

}
