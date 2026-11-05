//
//  DeviceFieldsAssembler.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Retrieves and merges device, application, and custom subscription fields.
///
/// Fields are merged in the following order:
///
/// 1. Device fields.
/// 2. Application fields.
/// 3. Custom fields.
///
/// Values from later sources replace values with the same key from earlier
/// sources.
///
/// - Parameters:
///   - appFields: Application fields derived from SDK configuration.
///   - customFieldsData: Encoded custom fields stored in the entity.
/// - Returns: Merged subscription fields.
@_spi(_Altcraft) public func getFields(
    appFields: [String: String],
    customFieldsData: Data?
) async -> [String: Any] {
    let deviceFields = await DeviceInfo.getDeviceFields()
    var fields: [String: Any] = deviceFields.asDictionary()

    fields.merge(appFields) { _, newValue in
        newValue
    }

    if let customFieldsData,
       let object = try? JSONSerialization.jsonObject(
           with: customFieldsData
       ),
       let customFields = object as? [String: Any] {
        fields.merge(customFields) { _, newValue in
            newValue
        }
    }

    return fields
}
