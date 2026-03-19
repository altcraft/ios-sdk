//
//  AltcraftPushReceiverTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import XCTest
import UserNotifications
@testable import Altcraft

/**
* AltcraftPushReceiverTests
*
* Positive scenarios:
* - test_1: isAltcraftPush detects flag correctly.
* - test_2: applyImageAttachment creates JPG attachment from JPEG data.
* - test_3: applyImageAttachment with unknown format uses JPG fallback.
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
}
