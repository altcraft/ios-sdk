//
//  InAppEntity+CoreDataProperties.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

typealias InAppEntityCoreDataPropertiesSet = NSSet

extension InAppEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<InAppEntity> {
        return NSFetchRequest<InAppEntity>(entityName: "InAppEntity")
    }

    @NSManaged var acid: String?
    @NSManaged var actionTriggerName: String?
    @NSManaged var actionTriggerType: String?
    @NSManaged var appVersionCondition: String?
    @NSManaged var appVersions: Data?
    @NSManaged var availability: Data?
    @NSManaged var checksum: String?
    @NSManaged var companyId: Int32
    @NSManaged var contentUrl: String?
    @NSManaged var deadline: Int64
    @NSManaged var endDate: Int64
    @NSManaged var images: Data?
    @NSManaged var impressionsLimit: Int32
    @NSManaged var isAnonim: Bool
    @NSManaged var lastCompanyUpdate: Int64
    @NSManaged var placements: Data?
    @NSManaged var policy: Data?
    @NSManaged var priority: Int16
    @NSManaged var smid: String?
    @NSManaged var triggerEvents: Data?
    @NSManaged var type: String?
    @NSManaged var uid: String?
}
