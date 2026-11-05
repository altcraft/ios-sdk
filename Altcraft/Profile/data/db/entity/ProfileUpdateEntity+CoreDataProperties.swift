//
//  ProfileUpdateEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias ProfileUpdateEntityCoreDataPropertiesSet = NSSet

extension ProfileUpdateEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<ProfileUpdateEntity> {
        return NSFetchRequest<ProfileUpdateEntity>(entityName: "ProfileUpdateEntity")
    }

    @NSManaged var maxRetryCount: Int16
    @NSManaged var profileFields: Data?
    @NSManaged var requestId: String?
    @NSManaged var retryCount: Int16
    @NSManaged var skipTriggers: Bool
    @NSManaged var time: Int64
    @NSManaged var userTag: String?

}
