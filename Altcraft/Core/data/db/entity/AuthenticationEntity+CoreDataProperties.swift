//
//  AuthenticationEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

typealias AuthenticationEntityCoreDataPropertiesSet = NSSet

extension AuthenticationEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<AuthenticationEntity> {
        return NSFetchRequest<AuthenticationEntity>(entityName: "AuthenticationEntity")
    }

    @NSManaged var anonimAcid: String?
    @NSManaged var currentAcid: String?
    @NSManaged var deviceId: String?
    @NSManaged var currentUserTag: String?
    @NSManaged var startAnonSession: Int64
    @NSManaged var isTest: Bool
}
