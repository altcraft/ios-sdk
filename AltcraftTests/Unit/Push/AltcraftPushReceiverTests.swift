//
//  AltcraftPushReceiverTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
import UserNotifications
@testable import Altcraft

/**
 * AltcraftPushReceiverTests
 *
 * Positive scenarios:
 *  - test_1: isAltcraftPush → detects flag correctly.
 *  - test_2: applyImageAttachment → creates JPG attachment from temp JPEG.
 *  - test_3: applyImageAttachment with unknown format → uses JPG fallback.
 */
final class AltcraftPushReceiverTests: XCTestCase {

    // MARK: - Helpers

    private func makeTempDir(_ name: String = UUID().uuidString) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(name, isDirectory: true)
    }

    /// Minimal JPEG data (same idea as in the previous tests).
    private func makeSampleJPEGData() -> Data {
        Data(
            [0xFF,0xD8,0xFF,0xE0, 0x00,0x10, 0x4A,0x46,0x49,0x46,0x00,0x01]
            + Array(repeating: 0, count: 64)
        )
    }

    /// Just random bytes so the format is most likely not recognized.
    private func makeRandomData() -> Data {
        Data(Array(repeating: 0xAB, count: 32))
    }

    @discardableResult
    private func writeTempFile(
        data: Data,
        ext: String? = nil,
        fileName: String = UUID().uuidString
    ) throws -> URL {
        let dir = makeTempDir("AltcraftPushReceiverTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(
            fileName + (ext.map { ".\($0)" } ?? ""),
            isDirectory: false
        )
        try data.write(to: url, options: .atomic)
        return url
    }

    private func makeRequest(userInfo: [AnyHashable: Any]) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        content.title = "t"
        content.body = "b"
        return UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
    }

    // MARK: - Tests

    /// test_1: isAltcraftPush detects flag correctly
    func test_1_isAltcraftPush_detectsFlag_correctly() {
        let svc = AltcraftPushReceiver()
        let reqYes = makeRequest(userInfo: ["_ac_push": true])
        let reqNo  = makeRequest(userInfo: ["something": 1])

        XCTAssertTrue(svc.isAltcraftPush(reqYes))
        XCTAssertFalse(svc.isAltcraftPush(reqNo))
    }

    /// test_2: applyImageAttachment from temp JPEG creates JPG attachment
    ///
    /// This is the analogue of the previous "createNotificationAttachment" test.
    /// We verify that:
    ///  - a single attachment is created;
    ///  - the file actually exists on disk;
    ///  - the extension is "jpg".
    func test_2_applyImageAttachment_fromTempJPEG_createsJPGAttachment() throws {
        let svc = AltcraftPushReceiver()
        let tmp = try writeTempFile(data: makeSampleJPEGData(), ext: "tmp")
        let content = UNMutableNotificationContent()

        try svc.applyImageAttachment(from: tmp, to: content)

        XCTAssertEqual(content.attachments.count, 1)

        let att = content.attachments[0]
        XCTAssertEqual(att.identifier, "img")
        XCTAssertEqual(att.url.pathExtension, "jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: att.url.path))
    }

    /// test_3: applyImageAttachment with unknown format uses JPG fallback
    ///
    /// We verify the fallback behaviour:
    /// if the format is not recognized, the code uses `format?.fileExtension ?? "jpg"`,
    /// so the resulting extension must be "jpg".
    func test_3_applyImageAttachment_unknownFormat_usesJPGFallback() throws {
        let svc = AltcraftPushReceiver()
        let tmp = try writeTempFile(data: makeRandomData(), ext: "bin")
        let content = UNMutableNotificationContent()

        try svc.applyImageAttachment(from: tmp, to: content)

        XCTAssertEqual(content.attachments.count, 1)

        let att = content.attachments[0]
        XCTAssertEqual(att.identifier, "img")
        XCTAssertEqual(att.url.pathExtension, "jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: att.url.path))
    }
}
