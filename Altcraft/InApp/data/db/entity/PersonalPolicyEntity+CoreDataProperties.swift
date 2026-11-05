//
//  PersonalPolicyEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias PersonalPolicyEntityCoreDataPropertiesSet = NSSet

extension PersonalPolicyEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<PersonalPolicyEntity> {
        return NSFetchRequest<PersonalPolicyEntity>(entityName: "PersonalPolicyEntity")
    }

    @NSManaged var acid: String?
    @NSManaged var smid: String?
    @NSManaged var openCount: Int32
    @NSManaged var deliveryReport: Bool
}
