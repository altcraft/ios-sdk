//
//  AuthRequestEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias AuthRequestEntityCoreDataPropertiesSet = NSSet

extension AuthRequestEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<AuthRequestEntity> {
        return NSFetchRequest<AuthRequestEntity>(entityName: "AuthRequestEntity")
    }

    @NSManaged var requestId: String?
    @NSManaged var userTag: String?
    @NSManaged var retryCount: Int16
    @NSManaged var maxRetryCount: Int16

}
