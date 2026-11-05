//
//  AltcraftPushReceiverTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import UserNotifications
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
* AltcraftPushReceiverTests
*
 * Positive scenarios:
 * - test_1: isAltcraftPush detects flag correctly.
 * - test_2: applyImageAttachment creates JPG attachment from JPEG data.
 * - test_3: applyImageAttachment with unknown format uses JPG fallback.
 * - test_4: takePush invokes the handler exactly once; a subsequent
 *   serviceExtensionTimeWillExpire() call does not invoke it again.
 * - test_5: concurrent takePush calls keep handlers isolated — each handler
 *   receives its own push content, never another push's content.
 *
 */
final class AltcraftPushReceiverTests: XCTestCase {

    private func makeRequest(userInfo: [AnyHashable: Any]) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        content.title = "title"
        content.body = "body"

        return UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
    }

    private func makeSampleJPEGData() -> Data {
        Data(
            [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01]
            + Array(repeating: 0, count: 64)
        )
    }

    private func makeRandomData() -> Data {
        Data(Array(repeating: 0xAB, count: 32))
    }

    /// test_1: isAltcraftPush detects flag correctly
    func test_1_is_altcraft_push_detects_flag_correctly() {
        let receiver = AltcraftPushReceiver()
        let altcraftRequest = makeRequest(userInfo: ["_ac_push": true])
        let regularRequest = makeRequest(userInfo: ["other_key": 1])

        XCTAssertTrue(receiver.isAltcraftPush(altcraftRequest))
        XCTAssertFalse(receiver.isAltcraftPush(regularRequest))
    }

    /// test_2: applyImageAttachment creates JPG attachment from JPEG data
    func test_2_apply_image_attachment_creates_jpg_attachment_from_jpeg_data() throws {
        let receiver = AltcraftPushReceiver()
        let content = UNMutableNotificationContent()

        try receiver.applyImageAttachment(
            from: makeSampleJPEGData(),
            to: content
        )

        XCTAssertEqual(content.attachments.count, 1)

        let attachment = content.attachments[0]
        XCTAssertEqual(attachment.identifier, "img")
        XCTAssertEqual(attachment.url.pathExtension, "jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachment.url.path))
    }

    /// test_3: applyImageAttachment with unknown format uses JPG fallback
    func test_3_apply_image_attachment_with_unknown_format_uses_jpg_fallback() throws {
        let receiver = AltcraftPushReceiver()
        let content = UNMutableNotificationContent()

        try receiver.applyImageAttachment(
            from: makeRandomData(),
            to: content
        )

        XCTAssertEqual(content.attachments.count, 1)

        let attachment = content.attachments[0]
        XCTAssertEqual(attachment.identifier, "img")
        XCTAssertEqual(attachment.url.pathExtension, "jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachment.url.path))
    }

    /// test_4: takePush invokes the handler exactly once; a subsequent
    /// serviceExtensionTimeWillExpire() call does not invoke it again.
    func test_4_take_push_delivers_handler_exactly_once() {
        let receiver = AltcraftPushReceiver()
        let request = makeRequest(userInfo: ["_ac_push": true])

        let delivered = expectation(description: "handler delivered once")
        delivered.assertForOverFulfill = true

        receiver.takePush(request) { content in
            XCTAssertEqual(content.title, "title")
            delivered.fulfill()
        }

        wait(for: [delivered], timeout: 5)

        receiver.serviceExtensionTimeWillExpire()
    }

    /// test_5: concurrent takePush calls keep handlers isolated — each handler
    /// receives its own push content, never another push's content.
    func test_5_concurrent_pushes_keep_isolated_handlers() {
        let receiver = AltcraftPushReceiver()

        let firstContent = UNMutableNotificationContent()
        firstContent.title = "first"
        firstContent.userInfo = ["_ac_push": true]
        let firstRequest = UNNotificationRequest(
            identifier: "first", content: firstContent, trigger: nil
        )

        let secondContent = UNMutableNotificationContent()
        secondContent.title = "second"
        secondContent.userInfo = ["_ac_push": true]
        let secondRequest = UNNotificationRequest(
            identifier: "second", content: secondContent, trigger: nil
        )

        let firstDelivered = expectation(description: "first handler delivered")
        firstDelivered.assertForOverFulfill = true
        let secondDelivered = expectation(description: "second handler delivered")
        secondDelivered.assertForOverFulfill = true

        receiver.takePush(firstRequest) { content in
            XCTAssertEqual(content.title, "first")
            firstDelivered.fulfill()
        }
        receiver.takePush(secondRequest) { content in
            XCTAssertEqual(content.title, "second")
            secondDelivered.fulfill()
        }

        wait(for: [firstDelivered, secondDelivered], timeout: 5)

        receiver.serviceExtensionTimeWillExpire()
    }
}
