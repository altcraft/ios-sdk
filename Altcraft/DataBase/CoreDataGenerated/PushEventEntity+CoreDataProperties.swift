//
//  PushEventEntity+CoreDataProperties.swift
//  
//
//  Created by andrey on 03.03.2026.
//
//

public import Foundation
public import CoreData


public typealias PushEventEntityCoreDataPropertiesSet = NSSet

extension PushEventEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PushEventEntity> {
        return NSFetchRequest<PushEventEntity>(entityName: "PushEventEntity")
    }

    @NSManaged public var maxRetryCount: Int16
    @NSManaged public var requestId: String?
    @NSManaged public var retryCount: Int16
    @NSManaged public var time: Int64
    @NSManaged public var type: String?
    @NSManaged public var uid: String?

}
