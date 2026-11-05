//
//  MapBuilderTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import AltcraftCore
@_spi(_Altcraft) import AltcraftCore
#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif
#if canImport(AltcraftPush)
@_spi(_Altcraft) import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@_spi(_Altcraft) import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@_spi(_Altcraft) import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@_spi(_Altcraft) import AltcraftTarget
#endif
#if canImport(AltcraftCore)
@testable import AltcraftCore
#endif
#if canImport(AltcraftPush)
@testable import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@testable import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@testable import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@testable import AltcraftTarget
#endif

/**
 * MapBuilderTests
 *
 * Positive scenarios:
 *  - test_1: createEventValue with PushEventRequestData includes http_code and merged event data.
 *  - test_2: createEventValue with request that has nil eventData returns only http_code.
 *  - test_3: createEventValue with nil response still includes http_code and request event data.
 */

final class MapBuilderTests: IsolatedTestCase {

    /// test_1: createEventValue with PushEventRequestData includes http_code and merged event data
    func test_1_createEventValue_includesHttpCodeAndMergedData() {
        let request = RequestModel.PushEventRequestData(
            path: PushConstants.UrlPath.event,
            requestId: "RID-1",
            time: 1000,
            type: PushConstants.PushEvents.delivery,
            uid: "UID-1",
        )
        let response = ResponseModel.AsyncResponse(
            error: nil,
            errorText: nil
        )

        let eventValue = MapBuilder.createEventValue(
            code: 200,
            response: response,
            request: request
        )

        let ev = eventValue.eventValue
        XCTAssertEqual(ev?[MapBuilder.httpCodeKey] as? Int, 200)
        XCTAssertEqual(ev?[Constants.MapKeys.uid] as? String, "UID-1")
        XCTAssertEqual(ev?[Constants.MapKeys.type] as? String, PushConstants.PushEvents.delivery)
    }

    /// test_2: createEventValue with request that has nil eventData returns only http_code
    func test_2_createEventValue_withNilEventData_returnsOnlyHttpCode() {
        let request = RequestModel.PushStatusRequestData(
            path: PushConstants.UrlPath.status,
            requestId: "RID-2",
            provider: "ios-apns",
            token: "TOK"
        )

        let eventValue = MapBuilder.createEventValue(
            code: 404,
            response: nil as ResponseModel.ResponseWithProfile?,
            request: request
        )

        let ev = eventValue.eventValue
        XCTAssertEqual(ev?[MapBuilder.httpCodeKey] as? Int, 404)
        XCTAssertNil(ev?[Constants.MapKeys.uid])
        XCTAssertNil(ev?[Constants.MapKeys.type])
    }

    /// test_3: createEventValue with nil response still includes http_code and request event data
    func test_3_createEventValue_withNilResponse_includesHttpCode() {
        let request = RequestModel.PushEventRequestData(
            path: PushConstants.UrlPath.event,
            requestId: "RID-3",
            time: 2000,
            type: PushConstants.PushEvents.open,
            uid: "UID-3",
        )

        let eventValue = MapBuilder.createEventValue(
            code: 503,
            response: nil as ResponseModel.AsyncResponse?,
            request: request
        )

        let ev = eventValue.eventValue
        XCTAssertEqual(ev?[MapBuilder.httpCodeKey] as? Int, 503)
        XCTAssertEqual(ev?[Constants.MapKeys.uid] as? String, "UID-3")
        XCTAssertEqual(ev?[Constants.MapKeys.type] as? String, PushConstants.PushEvents.open)
    }

    // MARK: - unionMaps (device + custom + AppInfo)

    /// test_4: unionMaps merges device fields, user custom fields and AppInfo
    /// with the correct precedence: device < custom < AppInfo.
    func test_4_unionMaps_mergesDeviceCustomAndAppInfo_withCorrectPrecedence() async {
        _ = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://api.altcraft.test",
                rToken: "rt",
                appInfo: AppInfo(appID: "app-id-4", appIID: "iid-4", appVer: "9.9.9")
            )
            .build()
        )

        // Overlapping key "a":
        //   device  = "device-a"
        //   custom  = "custom-a"  (must override device)
        //   AppInfo = not present under "a"
        // Unique keys are preserved.
        let merged = await MapBuilder.unionMaps(
            ["a": "custom-a", "customOnly": "c1"]
        )

        // AppInfo precedence: _app_* keys come from AppInfo.
        XCTAssertEqual(merged["_app_id"] as? String, "app-id-4")
        XCTAssertEqual(merged["_app_iid"] as? String, "iid-4")
        XCTAssertEqual(merged["_app_ver"] as? String, "9.9.9")
        // User custom field survives.
        XCTAssertEqual(merged["customOnly"] as? String, "c1")
        // User "a" overrides device "a".
        XCTAssertEqual(merged["a"] as? String, "custom-a")
    }

    /// test_5: unionMaps with nil customFields still returns device + AppInfo keys.
    func test_5_unionMaps_withNilCustomFields_returnsDeviceAndAppInfo() async {
        _ = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://api.altcraft.test",
                rToken: "rt",
                appInfo: AppInfo(appID: "app-id-5", appIID: "iid-5", appVer: "1.0.0")
            )
            .build()
        )

        let merged = await MapBuilder.unionMaps(nil)

        // Device fields are present (always populated by DeviceInfo).
        XCTAssertEqual(merged["_os"] as? String, "IOS")
        XCTAssertEqual(merged["_device_type"] as? String, "mob")
        XCTAssertNotNil(merged["_device_model"])
        XCTAssertNotNil(merged["_os_ver"])
        // AppInfo fields are present.
        XCTAssertEqual(merged["_app_id"] as? String, "app-id-5")
        XCTAssertEqual(merged["_app_ver"] as? String, "1.0.0")
    }

    /// test_6: unionMaps without AppInfo in configuration still returns device + customFields.
    func test_6_unionMaps_withoutAppInfo_returnsDeviceAndCustomFields() async {
        _ = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://api.altcraft.test",
                rToken: "rt"
            )
            .build()
        )

        let merged = await MapBuilder.unionMaps(
            ["onlyCustom": "x"]
        )

        // Device fields present.
        XCTAssertEqual(merged["_os"] as? String, "IOS")
        // User custom field present.
        XCTAssertEqual(merged["onlyCustom"] as? String, "x")
        // AppInfo keys absent (not set).
        XCTAssertNil(merged["_app_id"])
        XCTAssertNil(merged["_app_iid"])
        XCTAssertNil(merged["_app_ver"])
    }

    /// test_7: unionMaps without SDK configuration returns device + customFields
    /// (AppInfo contribution silently dropped, no throw).
    func test_7_unionMaps_withoutConfiguration_returnsDeviceAndCustomFields() async {
        // Ensure no configuration is stored (fresh context for this test).
        let context = CoreDataManager.shared.getContext()
        context.performAndWait {
            for entity in (try? context.fetch(NSFetchRequest<NSManagedObject>(
                entityName: Constants.EntityNames.configurationEntity
            ))) ?? [] {
                context.delete(entity)
            }
            try? context.save()
        }

        let merged = await MapBuilder.unionMaps(
            ["noConfig": "y"]
        )

        // Device fields still present.
        XCTAssertEqual(merged["_os"] as? String, "IOS")
        // User custom field present.
        XCTAssertEqual(merged["noConfig"] as? String, "y")
        // AppInfo absent (no config).
        XCTAssertNil(merged["_app_id"])
    }
}
