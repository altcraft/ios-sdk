//
//  ProfileUpdateEntity+CoreDataProperties.swift
//  
//
//  Created by andrey on 03.03.2026.
//
//

public import Foundation
public import CoreData


public typealias ProfileUpdateEntityCoreDataPropertiesSet = NSSet

extension ProfileUpdateEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProfileUpdateEntity> {
        return NSFetchRequest<ProfileUpdateEntity>(entityName: "ProfileUpdateEntity")
    }

    @NSManaged public var maxRetryCount: Int16
    @NSManaged public var profileFields: Data?
    @NSManaged public var requestId: String?
    @NSManaged public var retryCount: Int16
    @NSManaged public var skipTriggers: Bool
    @NSManaged public var time: Int64
    @NSManaged public var userTag: String?

}
