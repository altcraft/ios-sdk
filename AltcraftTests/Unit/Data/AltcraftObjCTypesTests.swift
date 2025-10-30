//
//  AltcraftObjCTypesTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * AltcraftObjCTypesTests
 *
 * Positive scenarios:
 *  - test_1_AppInfoObjC_initialization: AppInfoObjC correctly stores app metadata.
 *  - test_2_CategoryDataObjC_fromSwift_withAllFields: CategoryDataObjC.fromSwift handles complete data.
 *  - test_3_CategoryDataObjC_fromSwift_withRequiredFieldsOnly: CategoryDataObjC.fromSwift handles minimal data.
 *  - test_4_CategoryDataObjC_toSwiftArray: Converts ObjC array to Swift array correctly.
 *  - test_5_ResponseWithHttpObjC_fromSwift_withCompleteData: ResponseWithHttpObjC handles complete response.
 *  - test_6_ResponseWithHttpObjC_fromSwift_withNilResponse: ResponseWithHttpObjC handles nil response gracefully.
 *  - test_7_TokenDataObjC_fromSwift_validToken: TokenDataObjC converts valid Swift token.
 *  - test_8_SubscriptionConversions_allTypes: All subscription types convert between ObjC/Swift correctly.
 *  - test_9_toJSONValue_allSupportedTypes: JSON conversion handles all supported types.
 *
 * Edge scenarios:
 *  - test_10_CategoryDataObjC_fromSwift_withMissingName_returnsNil: CategoryDataObjC.fromSwift requires name.
 *  - test_11_TokenDataObjC_fromSwift_invalidToken_returnsNil: TokenDataObjC rejects empty provider/token.
 *  - test_12_toJSONValue_unsupportedTypes_returnsNil: JSON conversion rejects unsupported types.
 *  - test_13_mapNSDictionary_withComplexNestedStructure: Handles complex nested dictionaries/arrays.
 *  - test_14_SubscriptionConversions_withNilOptionalFields: Subscriptions handle nil optional fields.
 */
final class AltcraftObjCTypesTests: XCTestCase {

    /// test_1_AppInfoObjC_initialization
    func test_1_AppInfoObjC_initialization() {
        let appInfo = AppInfoObjC(
            appID: "test.app.id",
            appIID: "install123",
            appVer: "1.0.0"
        )

        XCTAssertEqual(appInfo.appID, "test.app.id")
        XCTAssertEqual(appInfo.appIID, "install123")
        XCTAssertEqual(appInfo.appVer, "1.0.0")
    }

    /// test_2_CategoryDataObjC_fromSwift_withAllFields
    func test_2_CategoryDataObjC_fromSwift_withAllFields() {
        let swiftCategory = CategoryData(
            name: "news",
            title: "News Updates",
            steady: true,
            active: true
        )

        guard let objcCategory = CategoryDataObjC.fromSwift(swiftCategory) else {
            XCTFail("CategoryDataObjC.fromSwift should not return nil for valid data")
            return
        }

        XCTAssertEqual(objcCategory.name, "news")
        XCTAssertEqual(objcCategory.title, "News Updates")
        XCTAssertTrue(objcCategory.steady)
        XCTAssertTrue(objcCategory.active)
    }

    /// test_3_CategoryDataObjC_fromSwift_withRequiredFieldsOnly
    func test_3_CategoryDataObjC_fromSwift_withRequiredFieldsOnly() {
        let swiftCategory = CategoryData(
            name: "sports",
            title: nil,
            steady: nil,
            active: false
        )

        guard let objcCategory = CategoryDataObjC.fromSwift(swiftCategory) else {
            XCTFail("CategoryDataObjC.fromSwift should not return nil for minimal valid data")
            return
        }

        XCTAssertEqual(objcCategory.name, "sports")
        XCTAssertEqual(objcCategory.title, "")
        XCTAssertFalse(objcCategory.steady)
        XCTAssertFalse(objcCategory.active)
    }

    /// test_10_CategoryDataObjC_fromSwift_withMissingName_returnsNil
    func test_10_CategoryDataObjC_fromSwift_withMissingName_returnsNil() {
        let swiftCategory = CategoryData(
            name: nil,
            title: nil,
            steady: nil,
            active: nil
        )

        let objcCategory = CategoryDataObjC.fromSwift(swiftCategory)

        XCTAssertNil(objcCategory, "CategoryDataObjC.fromSwift should return nil when name is missing")
    }

    /// test_4_CategoryDataObjC_toSwiftArray
    func test_4_CategoryDataObjC_toSwiftArray() {
        let objcCategories = [
            CategoryDataObjC(name: "cat1", title: "Category 1", steady: true, active: true),
            CategoryDataObjC(name: "cat2", title: "Category 2", steady: false, active: true)
        ]

        let swiftCategories = CategoryDataObjC.toSwiftArray(objcCategories)

        XCTAssertEqual(swiftCategories?.count, 2)
        XCTAssertEqual(swiftCategories?[0].name, "cat1")
        XCTAssertEqual(swiftCategories?[1].name, "cat2")
        XCTAssertEqual(swiftCategories?[0].title, "Category 1")
        XCTAssertEqual(swiftCategories?[0].steady, true)
        XCTAssertEqual(swiftCategories?[0].active, true)
    }

    /// test_5_ResponseWithHttpObjC_fromSwift_withCompleteData
    func test_5_ResponseWithHttpObjC_fromSwift_withCompleteData() {
        let categoryData = CategoryData(
            name: "news",
            title: "News",
            steady: true,
            active: true
        )
        
        let subscriptionData = SubscriptionData(
            subscriptionId: "sub-123",
            hashId: "hash-123",
            provider: "ios-apns",
            status: "active",
            fields: ["key": .string("value")],
            cats: [categoryData]
        )
        
        let profileData = ProfileData(
            id: "profile-123",
            status: "active",
            isTest: false,
            subscription: subscriptionData
        )
        
        let response = Response(
            error: 0,
            errorText: "Success",
            profile: profileData
        )
        
        let swiftResponse = ResponseWithHttp(httpCode: 200, response: response)

        guard let objcResponse = ResponseWithHttpObjC.from(swiftResponse) else {
            XCTFail("ResponseWithHttpObjC.from should not return nil for valid response")
            return
        }

        XCTAssertEqual(objcResponse.httpCode, 200)
        XCTAssertNotNil(objcResponse.responseJSON)
        
        if let json = objcResponse.responseJSON {
            XCTAssertEqual(json["error"] as? Int, 0)
            XCTAssertEqual(json["error_text"] as? String, "Success")
            XCTAssertNotNil(json["profile"])
        }
    }

    /// test_6_ResponseWithHttpObjC_fromSwift_withNilResponse
    func test_6_ResponseWithHttpObjC_fromSwift_withNilResponse() {
        let swiftResponse = ResponseWithHttp(httpCode: 404, response: nil)

        guard let objcResponse = ResponseWithHttpObjC.from(swiftResponse) else {
            XCTFail("ResponseWithHttpObjC.from should not return nil even with nil response")
            return
        }

        XCTAssertEqual(objcResponse.httpCode, 404)
        XCTAssertNil(objcResponse.responseJSON)
    }

    /// test_7_TokenDataObjC_fromSwift_validToken
    func test_7_TokenDataObjC_fromSwift_validToken() {
        let swiftToken = TokenData(provider: "ios-apns", token: "device-token-123")

        guard let objcToken = TokenDataObjC.from(swiftToken) else {
            XCTFail("TokenDataObjC.from should not return nil for valid token")
            return
        }

        XCTAssertEqual(objcToken.provider, "ios-apns")
        XCTAssertEqual(objcToken.token, "device-token-123")
    }

    /// test_11_TokenDataObjC_fromSwift_invalidToken_returnsNil
    func test_11_TokenDataObjC_fromSwift_invalidToken_returnsNil() {
        let invalidTokens = [
            TokenData(provider: "", token: "valid-token"),
            TokenData(provider: "ios-apns", token: ""),
            TokenData(provider: "", token: "")
        ]

        for invalidToken in invalidTokens {
            let objcToken = TokenDataObjC.from(invalidToken)
            XCTAssertNil(objcToken, "TokenDataObjC.from should return nil for invalid token: \(invalidToken)")
        }
    }

    /// test_8_SubscriptionConversions_allTypes
    func test_8_SubscriptionConversions_allTypes() {
        // Test EmailSubscription
        let emailSubObjC = EmailSubscriptionObjC(
            resourceId: NSNumber(value: 123),
            email: "test@example.com",
            status: "active",
            priority: NSNumber(value: 5),
            customFields: ["key": "value"],
            cats: ["news", "sports"]
        )

        if let swiftEmailSub = emailSubObjC.toSwift() as? EmailSubscription {
            XCTAssertEqual(swiftEmailSub.resourceId, 123)
            XCTAssertEqual(swiftEmailSub.email, "test@example.com")
            XCTAssertEqual(swiftEmailSub.status, "active")
            XCTAssertEqual(swiftEmailSub.priority, 5)
            
            if case .string(let value) = swiftEmailSub.customFields?["key"] {
                XCTAssertEqual(value, "value")
            } else {
                XCTFail("Custom field 'key' should be a string")
            }
            XCTAssertEqual(swiftEmailSub.cats, ["news", "sports"])
        } else {
            XCTFail("EmailSubscriptionObjC.toSwift should return EmailSubscription")
        }

        let smsSubObjC = SmsSubscriptionObjC(
            resourceId: NSNumber(value: 456),
            phone: "+1234567890",
            status: "pending",
            priority: NSNumber(value: 3),
            customFields: ["verified": true],
            cats: ["alerts"]
        )

        if let swiftSmsSub = smsSubObjC.toSwift() as? SmsSubscription {
            XCTAssertEqual(swiftSmsSub.resourceId, 456)
            XCTAssertEqual(swiftSmsSub.phone, "+1234567890")
            XCTAssertEqual(swiftSmsSub.status, "pending")
            XCTAssertEqual(swiftSmsSub.priority, 3)
            if case .bool(let value) = swiftSmsSub.customFields?["verified"] {
                XCTAssertTrue(value)
            } else {
                XCTFail("Custom field 'verified' should be a bool")
            }
            XCTAssertEqual(swiftSmsSub.cats, ["alerts"])
        } else {
            XCTFail("SmsSubscriptionObjC.toSwift should return SmsSubscription")
        }

        let pushSubObjC = PushSubscriptionObjC(
            resourceId: NSNumber(value: 789),
            provider: "ios-apns",
            subscriptionId: "push-sub-123",
            status: "active",
            priority: NSNumber(value: 2),
            customFields: ["device": "iPhone"],
            cats: ["notifications"]
        )

        if let swiftPushSub = pushSubObjC.toSwift() as? PushSubscription {
            XCTAssertEqual(swiftPushSub.resourceId, 789)
            XCTAssertEqual(swiftPushSub.provider, "ios-apns")
            XCTAssertEqual(swiftPushSub.subscriptionId, "push-sub-123")
            XCTAssertEqual(swiftPushSub.status, "active")
            XCTAssertEqual(swiftPushSub.priority, 2)
            if case .string(let value) = swiftPushSub.customFields?["device"] {
                XCTAssertEqual(value, "iPhone")
            } else {
                XCTFail("Custom field 'device' should be a string")
            }
            XCTAssertEqual(swiftPushSub.cats, ["notifications"])
        } else {
            XCTFail("PushSubscriptionObjC.toSwift should return PushSubscription")
        }

        let ccDataSubObjC = CcDataSubscriptionObjC(
            resourceId: NSNumber(value: 999),
            channel: "telegram_bot",
            ccData: ["chat_id": "12345"],
            status: "active",
            priority: NSNumber(value: 1),
            customFields: ["username": "test_user"],
            cats: ["messaging"]
        )

        if let swiftCcDataSub = ccDataSubObjC.toSwift() as? CcDataSubscription {
            XCTAssertEqual(swiftCcDataSub.resourceId, 999)
            XCTAssertEqual(swiftCcDataSub.channel, "telegram_bot")
            XCTAssertEqual(swiftCcDataSub.status, "active")
            XCTAssertEqual(swiftCcDataSub.priority, 1)
            if case .string(let value) = swiftCcDataSub.customFields?["username"] {
                XCTAssertEqual(value, "test_user")
            } else {
                XCTFail("Custom field 'username' should be a string")
            }
            XCTAssertEqual(swiftCcDataSub.cats, ["messaging"])
            
            if case .string(let chatId) = swiftCcDataSub.ccData["chat_id"] {
                XCTAssertEqual(chatId, "12345")
            } else {
                XCTFail("cc_data 'chat_id' should be a string")
            }
        } else {
            XCTFail("CcDataSubscriptionObjC.toSwift should return CcDataSubscription")
        }
    }

    /// test_14_SubscriptionConversions_withNilOptionalFields
    func test_14_SubscriptionConversions_withNilOptionalFields() {
        let pushSubObjC = PushSubscriptionObjC(
            resourceId: NSNumber(value: 789),
            provider: "ios-apns",
            subscriptionId: "sub-123",
            status: nil,
            priority: nil,
            customFields: nil,
            cats: nil
        )

        if let swiftPushSub = pushSubObjC.toSwift() as? PushSubscription {
            XCTAssertEqual(swiftPushSub.resourceId, 789)
            XCTAssertEqual(swiftPushSub.provider, "ios-apns")
            XCTAssertEqual(swiftPushSub.subscriptionId, "sub-123")
            XCTAssertNil(swiftPushSub.status)
            XCTAssertNil(swiftPushSub.priority)
            XCTAssertNil(swiftPushSub.customFields)
            XCTAssertNil(swiftPushSub.cats)
        } else {
            XCTFail("PushSubscriptionObjC.toSwift should return PushSubscription")
        }
    }
    /// test_9_toJSONValue_allSupportedTypes
    func test_9_toJSONValue_allSupportedTypes() {
        let stringSub = EmailSubscriptionObjC(
            resourceId: NSNumber(value: 1),
            email: "test@example.com",
            customFields: ["testString": "hello"]
        )
        
        if let swiftSub = stringSub.toSwift() as? EmailSubscription,
           case .string(let value) = swiftSub.customFields?["testString"] {
            XCTAssertEqual(value, "hello")
        } else {
            XCTFail("String should convert to .string JSONValue")
        }

        let numberSub = EmailSubscriptionObjC(
            resourceId: NSNumber(value: 1),
            email: "test@example.com",
            customFields: ["testNumber": 42]
        )
        
        if let swiftSub = numberSub.toSwift() as? EmailSubscription,
           case .number(let value) = swiftSub.customFields?["testNumber"] {
            XCTAssertEqual(value, 42.0, accuracy: 0.001)
        } else {
            XCTFail("Number should convert to .number JSONValue")
        }
        
        let boolSub = EmailSubscriptionObjC(
            resourceId: NSNumber(value: 1),
            email: "test@example.com",
            customFields: ["testBool": true]
        )
        
        if let swiftSub = boolSub.toSwift() as? EmailSubscription,
           case .bool(let value) = swiftSub.customFields?["testBool"] {
            XCTAssertTrue(value)
        } else {
            XCTFail("Boolean should convert to .bool JSONValue")
        }
    }

    /// test_12_toJSONValue_unsupportedTypes_returnsNil
    func test_12_toJSONValue_unsupportedTypes_returnsNil() {
        let dateSub = EmailSubscriptionObjC(
            resourceId: NSNumber(value: 1),
            email: "test@example.com",
            customFields: ["testDate": Date()]
        )
        
        if let swiftSub = dateSub.toSwift() as? EmailSubscription {
            XCTAssertNil(swiftSub.customFields?["testDate"])
        } else {
            XCTFail("Subscription should be created even with unsupported types")
        }
    }

    /// test_13_mapNSDictionary_withComplexNestedStructure
    func test_13_mapNSDictionary_withComplexNestedStructure() {
        let complexDict: NSDictionary = [
            "string": "value",
            "number": 42,
            "boolean": true,
            "null": NSNull(),
            "nestedDict": [
                "nestedKey": "nestedValue"
            ] as NSDictionary,
            "nestedArray": [1, "two", false] as NSArray
        ]
        
        let complexSub = EmailSubscriptionObjC(
            resourceId: NSNumber(value: 1),
            email: "test@example.com",
            customFields: complexDict
        )

        guard let swiftSub = complexSub.toSwift() as? EmailSubscription,
              let result = swiftSub.customFields else {
            XCTFail("Should convert complex dictionary")
            return
        }

        if case .string(let stringValue) = result["string"] {
            XCTAssertEqual(stringValue, "value")
        } else {
            XCTFail("String value should be preserved")
        }

        if case .number(let numberValue) = result["number"] {
            XCTAssertEqual(numberValue, 42.0, accuracy: 0.001)
        } else {
            XCTFail("Number value should be preserved")
        }

        if case .bool(let boolValue) = result["boolean"] {
            XCTAssertTrue(boolValue)
        } else {
            XCTFail("Boolean value should be preserved")
        }

        if case .null = result["null"] {
        } else {
            XCTFail("Null value should be preserved")
        }

        if case .object(let nestedDict) = result["nestedDict"] {
            if case .string(let nestedValue) = nestedDict["nestedKey"] {
                XCTAssertEqual(nestedValue, "nestedValue")
            } else {
                XCTFail("Nested dictionary value should be string")
            }
        } else {
            XCTFail("Nested dictionary should be preserved")
        }

        if case .array(let nestedArray) = result["nestedArray"] {
            XCTAssertEqual(nestedArray.count, 3)
            if case .number(let first) = nestedArray[0] {
                XCTAssertEqual(first, 1.0, accuracy: 0.001)
            } else {
                XCTFail("First array element should be number")
            }
            if case .string(let second) = nestedArray[1] {
                XCTAssertEqual(second, "two")
            } else {
                XCTFail("Second array element should be string")
            }
            if case .bool(let third) = nestedArray[2] {
                XCTAssertFalse(third)
            } else {
                XCTFail("Third array element should be bool")
            }
        } else {
            XCTFail("Nested array should be preserved")
        }
    }
}
