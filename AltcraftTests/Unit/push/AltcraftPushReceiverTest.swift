//
//  AltcraftPushReceiverTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import UserNotifications
@testable import Altcraft

/**
 * AltcraftPushReceiverTests (iOS 13 compatible)
 *
 * Coverage (concise, explicit names):
 *  - test_1_isAltcraftPush_detectsFlag_correctly
 *  - test_2_createNotificationAttachment_preservesExtension_and_setsIdentifier
 *  - test_3_addAttachment_swallowErrors_andLeavesAttachmentsEmpty
 *  - test_4_extractMediaURL_returnsURL_and_nilWhenMissing_emitsError
 *  - test_5_loadAttachmentAsync_fromLocalFile_addsAttachment
 *
 * Notes:
 *  - No network: download uses a local file:// URL.
 *  - Uses SDKEvents spy to assert event emission.
 *  - We do not call didReceive(): UNUserNotificationCenter.current() crashes under unit runner.
 */
final class AltcraftPushReceiverTests: XCTestCase {

    // MARK: - Event Spy

    private final class EventSpy {
        private(set) var events: [Event] = []

        func start() {
            SDKEvents.shared.subscribe { [weak self] ev in
                self?.events.append(ev)
            }
        }

        func stop() {
            SDKEvents.shared.unsubscribe()
        }
    }

    // MARK: - Helpers

    private func makeTempDir(_ name: String = UUID().uuidString) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name, isDirectory: true)
    }

    private func makeSampleJPEGData() -> Data {
        Data([0xFF,0xD8,0xFF,0xE0, 0x00,0x10, 0x4A,0x46,0x49,0x46,0x00,0x01] + Array(repeating: 0, count: 64))
    }

    @discardableResult
    private func writeTempFile(data: Data, ext: String? = nil, fileName: String = UUID().uuidString) throws -> URL {
        let dir = makeTempDir("AltcraftPushReceiverTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName + (ext.map { ".\($0)" } ?? ""), isDirectory: false)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func makeRequest(userInfo: [AnyHashable: Any]) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        content.title = "t"
        content.body = "b"
        return UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    }

    // MARK: - Tests

    /// test_1_isAltcraftPush_detectsFlag_correctly
    func test_1_isAltcraftPush_detectsFlag_correctly() {
        let svc = AltcraftPushReceiver()
        let reqYes = makeRequest(userInfo: ["_ac_push": true])
        let reqNo  = makeRequest(userInfo: ["something": 1])

        XCTAssertTrue(svc.isAltcraftPush(reqYes))
        XCTAssertFalse(svc.isAltcraftPush(reqNo))
    }

    /// test_2_createNotificationAttachment_preservesExtension_and_setsIdentifier
    func test_2_createNotificationAttachment_preservesExtension_and_setsIdentifier() throws {
        let svc = AltcraftPushReceiver()
        // source has .tmp but bytes are JPEG → must save as .jpg by detector
        let tempURL = try writeTempFile(data: makeSampleJPEGData(), ext: "tmp")
        let destDir = makeTempDir("attachments-\(UUID().uuidString)")

        let att = try svc.createNotificationAttachment(from: tempURL, in: destDir)

        XCTAssertTrue(att.url.lastPathComponent.hasSuffix(".jpg"))
        XCTAssertTrue(att.identifier.hasPrefix("image-jpg"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: att.url.path))
    }

    /// test_3_addAttachment_swallowErrors_andLeavesAttachmentsEmpty
    func test_3_addAttachment_swallowErrors_andLeavesAttachmentsEmpty() {
        let svc = AltcraftPushReceiver()
        let content = UNMutableNotificationContent()
        let nonExistingTemp = makeTempDir("nope").appendingPathComponent("missing.file")

        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        svc.addAttachment(to: content, from: nonExistingTemp, in: makeTempDir())

        XCTAssertEqual(content.attachments.count, 0)
        XCTAssertFalse(spy.events.isEmpty)
        XCTAssertTrue(spy.events.last is ErrorEvent)
        // function names are formatted as "addAttachment()"
        XCTAssertEqual(spy.events.last?.function, "addAttachment()")
    }

    /// test_4_extractMediaURL_returnsURL_and_nilWhenMissing_emitsError
    func test_4_extractMediaURL_returnsURL_and_nilWhenMissing_emitsError() throws {
        let svc = AltcraftPushReceiver()

        // valid
        let fileURL = try writeTempFile(data: makeSampleJPEGData(), ext: "jpg")
        let c1 = UNMutableNotificationContent()
        c1.userInfo = [Constants.UserInfoKeys.media: fileURL.absoluteString]
        XCTAssertEqual(svc.extractMediaURL(content: c1), fileURL)

        // missing/invalid
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        let c2 = UNMutableNotificationContent()
        c2.userInfo = ["foo": "bar"]
        XCTAssertNil(svc.extractMediaURL(content: c2))
        XCTAssertFalse(spy.events.isEmpty)
        XCTAssertTrue(spy.events.last is ErrorEvent)
        // formatted as "extractMediaURL()"
        XCTAssertEqual(spy.events.last?.function, "extractMediaURL()")
    }

    /// test_5_loadAttachmentAsync_fromLocalFile_addsAttachment
    func test_5_loadAttachmentAsync_fromLocalFile_addsAttachment() throws {
        let local = try writeTempFile(data: makeSampleJPEGData(), ext: "jpg")

        let content = UNMutableNotificationContent()
        content.userInfo = [
            "_ac_push": true,
            Constants.UserInfoKeys.media: local.absoluteString
        ]
        let req = UNNotificationRequest(identifier: "id", content: content, trigger: nil)

        let exp = expectation(description: "loadAttachment")
        req.loadAttachmentAsync { resultContent in
            XCTAssertEqual(resultContent.attachments.count, 1)
            XCTAssertTrue(resultContent.attachments[0].url.lastPathComponent.hasSuffix(".jpg"))
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)
    }
}

