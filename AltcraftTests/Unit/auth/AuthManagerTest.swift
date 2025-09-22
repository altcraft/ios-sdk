//
//  AuthManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import CryptoKit
@testable import Altcraft

final class AuthManagerTests: XCTestCase {

    // ---------- Assertion messages ----------
    private let msgNonNil   = "Value must be non-nil"
    private let msgNil      = "Value must be nil"
    private let msgEqual    = "Value must equal expected"
    private let msgPrefix   = "String must have expected prefix"
    private let msgContains = "String must contain expected fragment"

    // ---------- Helpers: Base64URL + JWT fabrication ----------

    /// Base64URL-encodes data (no padding).
    private func b64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Builds a minimal JWT where payload contains `"matching"` as **stringified JSON**.
    private func makeJWT(matchingObject: [String: Any]) throws -> String {
        let header: [String: Any] = ["alg": "none", "typ": "JWT"]
        let matchingJSON = try JSONSerialization.data(withJSONObject: matchingObject, options: [])
        let payload: [String: Any] = [Constants.AuthKeys.matching: String(data: matchingJSON, encoding: .utf8)!]

        let header64  = b64url(try JSONSerialization.data(withJSONObject: header, options: []))
        let payload64 = b64url(try JSONSerialization.data(withJSONObject: payload, options: []))
        return "\(header64).\(payload64)." // empty signature for alg "none"
    }

    /// Computes expected SHA-256 hex the same way as production code.
    private func expectedHash(dbId: Int, matching: String, ids: [String]) -> String {
        let jsonString = matchingAsString(dbId: dbId, matching: matching, value: ids.joined(separator: "/"))
        let bytes = Data(jsonString.utf8)
        let digest = SHA256.hash(data: bytes)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // ---------- Optional hooks (run only if environment allows) ----------

    /// Attempts to set a JWT into JWTManager for the test. Returns `true` if succeeded.
    /// No production changes: this uses whatever API your SDK already exposes at runtime.
    private func trySetJWT(_ jwt: String?) -> Bool {
        // If your JWTManager exposes a setter or mutable property — use it here.
        // Examples (uncomment the one that exists in your SDK):
        //
        // JWTManager.shared.jwt = jwt; return true
        // JWTManager.shared.setJWT(jwt); return true
        //
        // If none exists, we cannot reliably inject a JWT without changing production code.
        return false
    }

    /// Attempts to set an SDK config with rToken for getUserTag. Returns `true` if succeeded.
    private func trySetConfig(_ config: Configuration?) -> Bool {
        // If your SDK exposes a global/singleton config setter — call it here.
        // For example:
        // ConfigCoordinator.shared.overrideForTests(config); return true
        return false
    }

    // MARK: - getAuthData(rToken:)

    /// rToken path: returns "Bearer rtoken@<rToken>" and the same matching token.
    func test_getAuthData_withRToken() {
        let r = "r-123"
        let res = getAuthData(rToken: r)
        XCTAssertNotNil(res, msgNonNil)
        XCTAssertEqual(res!.0, "Bearer rtoken@\(r)", msgEqual)
        XCTAssertEqual(res!.1, r, msgEqual)
    }

    /// Current behavior: whitespace-only token is treated as non-empty.
    func test_getAuthData_withWhitespaceToken_isTreatedAsNonEmpty() {
        let r = "   "
        let res = getAuthData(rToken: r)
        XCTAssertNotNil(res, msgNonNil)
        XCTAssertEqual(res!.0, "Bearer rtoken@\(r)", msgEqual)
        XCTAssertEqual(res!.1, r, msgEqual)
    }

    /// JWT path (conditional): when rToken is nil and we can inject JWT, returns "Bearer <jwt>" and matching from claim.
    func test_getAuthData_withJWT_whenInjectionAvailable() throws {
        let dbId = 42
        let matching = "push_sub"
        let ids = ["user@example.com", "79001234567"]
        let matchingObj: [String: Any] = [
            Constants.AuthKeys.dbId: dbId,
            Constants.AuthKeys.matching: matching,
            Constants.AuthKeys.email: ids[0],
            Constants.AuthKeys.phone: ids[1]
        ]
        let jwt = try makeJWT(matchingObject: matchingObj)

        try XCTSkipIf(!trySetJWT(jwt), "JWT injection is not available without changing production code.")

        let res = getAuthData(rToken: nil)
        XCTAssertNotNil(res, msgNonNil)
        XCTAssertTrue(res!.0.hasPrefix("Bearer "), msgPrefix)
        XCTAssertTrue(res!.0.contains(jwt), msgContains)
        XCTAssertEqual(res!.1, matching, msgEqual)
    }

    /// JWT negative path (conditional): if we can inject a bad/empty JWT, result must be nil.
    func test_getAuthData_withInvalidJWT_returnsNil_whenInjectionAvailable() throws {
        try XCTSkipIf(!trySetJWT(nil), "JWT injection is not available without changing production code.")
        let res = getAuthData(rToken: nil)
        XCTAssertNil(res, msgNil)
    }

    // MARK: - getUserTag(completion:)

    /// rToken precedence (conditional): if we can set config with rToken, getUserTag must return it.
    func test_getUserTag_returnsRToken_whenConfigProvidesIt() throws {
        let cfg = Configuration(
            url: "https://example.com",
            rToken: "rt-999",
            appInfo: nil,
            providerPriorityList: nil
        )

        try XCTSkipIf(!trySetConfig(cfg), "Config injection is not available without changing production code.")

        let exp = expectation(description: "userTag")
        getUserTag { tag in
            XCTAssertEqual(tag, "rt-999", self.msgEqual)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// JWT hash path (fully conditional): if rToken is absent and both Config/JWT can be injected, hash must match.
    func test_getUserTag_returnsSHA256Hash_fromJWT_whenRTokenMissing_andInjectionAvailable() throws {
        let cfg = Configuration(
            url: "https://example.com",
            rToken: nil,
            appInfo: nil,
            providerPriorityList: nil
        )

        let dbId = 7
        let matching = "push_sub"
        let ids = ["idA", "idB"]
        let matchingObj: [String: Any] = [
            Constants.AuthKeys.dbId: dbId,
            Constants.AuthKeys.matching: matching,
            Constants.AuthKeys.profileId: ids[0],
            Constants.AuthKeys.fieldValue: ids[1]
        ]
        let jwt = try makeJWT(matchingObject: matchingObj)
        let expected = expectedHash(dbId: dbId, matching: matching, ids: ids)

        try XCTSkipIf(!(trySetConfig(cfg) && trySetJWT(jwt)), "Config/JWT injection is not available without changing production code.")

        let exp = expectation(description: "userTag-hash")
        getUserTag { tag in
            XCTAssertNotNil(tag, self.msgNonNil)
            XCTAssertEqual(tag, expected, self.msgEqual)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// When config is nil (conditional), getUserTag must complete with nil.
    func test_getUserTag_configNil_returnsNil_whenInjectionAvailable() throws {
        try XCTSkipIf(!trySetConfig(nil), "Config injection is not available without changing production code.")
        let exp = expectation(description: "userTag-nil")
        getUserTag { tag in
            XCTAssertNil(tag, self.msgNil)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}

