//
//  SubscribeEntity+CoreDataProperties.swift
//  
//
//  Created by andrey on 06.01.2026.
//
//

public import Foundation
public import CoreData


public typealias SubscribeEntityCoreDataPropertiesSet = NSSet

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
    @NSManaged public var requestId: String?
    @NSManaged public var userTag: String?
}
