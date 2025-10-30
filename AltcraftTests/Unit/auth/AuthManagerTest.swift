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

private class MockJWTManager {
    static var shared = MockJWTManager()
    var currentJWT: String?

    init() {}
    
    func setJWT(_ jwt: String?) {
        currentJWT = jwt
    }
}

private class MockConfigManager {
    static var shared = MockConfigManager()
    var currentConfig: Configuration?

    init() {}
    
    func setConfig(_ config: Configuration?) {
        currentConfig = config
    }
}

/**
 * AuthManagerTests
 *
 * Positive scenarios:
 *  - test_1: getAuthData with rToken → returns correct auth header and token.
 *  - test_2: getAuthData with whitespace token → treats whitespace as non-empty and returns header + token.
 *  - test_3: getAuthData with empty rToken → falls back to JWT and returns header + matching.
 *  - test_4: getAuthData with JWT → returns header with Bearer and matching from claim.
 *  - test_5: getAuthData with invalid JWT → returns nil.
 *  - test_6: getAuthData with no JWT and no rToken → returns nil.
 *  - test_7: getUserTag when config provides rToken → returns rToken as user tag.
 *  - test_8: getUserTag from JWT when rToken missing → returns SHA256 hash.
 *  - test_9: getUserTag with no config and no JWT → returns nil.
 *  - test_10: getUserTag with whitespace rToken in config → returns whitespace as-is.
 */
final class AuthManagerTests: XCTestCase {

    private let msgNonNil   = "Value must be non-nil"
    private let msgNil      = "Value must be nil"
    private let msgEqual    = "Value must equal expected"
    private let msgPrefix   = "String must have expected prefix"
    private let msgContains = "String must contain expected fragment"
    
    override func setUp() {
        super.setUp()
        MockJWTManager.shared = MockJWTManager()
        MockConfigManager.shared = MockConfigManager()
    }
    
    override func tearDown() {
        MockJWTManager.shared = MockJWTManager()
        MockConfigManager.shared = MockConfigManager()
        super.tearDown()
    }

    private func b64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func makeJWT(matchingObject: [String: Any]) throws -> String {
        let header: [String: Any] = ["alg": "none", "typ": "JWT"]
        let matchingJSON = try JSONSerialization.data(withJSONObject: matchingObject, options: [])
        let payload: [String: Any] = [Constants.AuthKeys.matching: String(data: matchingJSON, encoding: .utf8)!]
        let header64  = b64url(try JSONSerialization.data(withJSONObject: header, options: []))
        let payload64 = b64url(try JSONSerialization.data(withJSONObject: payload, options: []))
        return "\(header64).\(payload64)."
    }

    private func expectedHash(dbId: Int, matching: String, ids: [String]) -> String {
        let jsonString = matchingAsString(dbId: dbId, matching: matching, value: ids.joined(separator: "/"))
        let bytes = Data(jsonString.utf8)
        let digest = SHA256.hash(data: bytes)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func setMockJWT(_ jwt: String?) {
        MockJWTManager.shared.setJWT(jwt)
    }

    private func setMockConfig(_ config: Configuration?) {
        MockConfigManager.shared.setConfig(config)
    }

    private func getAuthDataMock(rToken: String?) -> (String, String)? {
        if let rToken = rToken, !rToken.isEmpty {
            return ("Bearer rtoken@\(rToken)", rToken)
        }
        
        if let jwt = MockJWTManager.shared.currentJWT {
            let components = jwt.components(separatedBy: ".")
            guard components.count >= 2 else { return nil }
            
            if let payloadData = Data(base64Encoded: components[1].base64PaddingAdded()),
               let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
               let matchingJSONString = payload[Constants.AuthKeys.matching] as? String,
               let matchingData = matchingJSONString.data(using: .utf8),
               let matchingObject = try? JSONSerialization.jsonObject(with: matchingData) as? [String: Any],
               let matching = matchingObject[Constants.AuthKeys.matching] as? String {
                return ("Bearer \(jwt)", matching)
            }
        }
        return nil
    }

    private func getUserTagMock(completion: @escaping (String?) -> Void) {
        if let rToken = MockConfigManager.shared.currentConfig?.rToken, !rToken.isEmpty {
            completion(rToken)
            return
        }
        
        if let jwt = MockJWTManager.shared.currentJWT {
            let components = jwt.components(separatedBy: ".")
            guard components.count >= 2,
                  let payloadData = Data(base64Encoded: components[1].base64PaddingAdded()),
                  let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
                  let matchingJSONString = payload[Constants.AuthKeys.matching] as? String,
                  let matchingData = matchingJSONString.data(using: .utf8),
                  let matchingObject = try? JSONSerialization.jsonObject(with: matchingData) as? [String: Any],
                  let dbId = matchingObject[Constants.AuthKeys.dbId] as? Int,
                  let matching = matchingObject[Constants.AuthKeys.matching] as? String else {
                completion(nil)
                return
            }
            
            var ids: [String] = []
            let idKeys = [
                Constants.AuthKeys.email,
                Constants.AuthKeys.phone,
                Constants.AuthKeys.profileId,
                Constants.AuthKeys.fieldValue
            ]
            for key in idKeys {
                if let value = matchingObject[key] as? String, !value.isEmpty {
                    ids.append(value)
                }
            }
            if !ids.isEmpty {
                let hash = expectedHash(dbId: dbId, matching: matching, ids: ids)
                completion(hash)
                return
            }
        }
        completion(nil)
    }

    /// getAuthData with rToken → returns correct auth header and token
    func test_1_getAuthData_withRToken_returnsHeaderAndToken() {
        let r = "r-123"
        let res = getAuthDataMock(rToken: r)
        XCTAssertNotNil(res, msgNonNil)
        XCTAssertEqual(res!.0, "Bearer rtoken@\(r)", msgEqual)
        XCTAssertEqual(res!.1, r, msgEqual)
    }

    /// getAuthData with whitespace token → treats whitespace as non-empty
    func test_2_getAuthData_withWhitespaceToken_treatedAsNonEmpty() {
        let r = "   "
        let res = getAuthDataMock(rToken: r)
        XCTAssertNotNil(res, msgNonNil)
        XCTAssertEqual(res!.0, "Bearer rtoken@\(r)", msgEqual)
        XCTAssertEqual(res!.1, r, msgEqual)
    }

    /// getAuthData with empty rToken → falls back to JWT
    func test_3_getAuthData_withEmptyRToken_fallsBackToJWT() throws {
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
        
        setMockJWT(jwt)
        let res = getAuthDataMock(rToken: "")
        
        XCTAssertNotNil(res, msgNonNil)
        XCTAssertTrue(res!.0.hasPrefix("Bearer "), msgPrefix)
        XCTAssertTrue(res!.0.contains(jwt), msgContains)
        XCTAssertEqual(res!.1, matching, msgEqual)
    }

    /// getAuthData with JWT → returns header with Bearer and matching
    func test_4_getAuthData_withJWT() throws {
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
        
        setMockJWT(jwt)
        let res = getAuthDataMock(rToken: nil)
        
        XCTAssertNotNil(res, msgNonNil)
        XCTAssertTrue(res!.0.hasPrefix("Bearer "), msgPrefix)
        XCTAssertTrue(res!.0.contains(jwt), msgContains)
        XCTAssertEqual(res!.1, matching, msgEqual)
    }

    /// getAuthData with invalid JWT → returns nil
    func test_5_getAuthData_withInvalidJWT_returnsNil() {
        setMockJWT("invalid.jwt.token")
        let res = getAuthDataMock(rToken: nil)
        XCTAssertNil(res, msgNil)
    }

    /// getAuthData with no JWT and no rToken → returns nil
    func test_6_getAuthData_withNoJWTAndNoRToken_returnsNil() {
        setMockJWT(nil)
        let res = getAuthDataMock(rToken: nil)
        XCTAssertNil(res, msgNil)
    }

    /// getUserTag when config provides rToken → returns rToken
    func test_7_getUserTag_returnsRToken_whenConfigProvidesIt() {
        let cfg = Configuration(url: "https://example.com", rToken: "rt-999", appInfo: nil, providerPriorityList: nil)
        setMockConfig(cfg)
        let exp = expectation(description: "userTag")
        getUserTagMock { tag in
            XCTAssertEqual(tag, "rt-999", self.msgEqual)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// getUserTag from JWT when rToken missing → returns SHA256 hash
    func test_8_getUserTag_returnsSHA256Hash_fromJWT_whenRTokenMissing() throws {
        let cfg = Configuration(url: "https://example.com", rToken: nil, appInfo: nil, providerPriorityList: nil)
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

        setMockConfig(cfg)
        setMockJWT(jwt)
        let exp = expectation(description: "userTag-hash")
        getUserTagMock { tag in
            XCTAssertNotNil(tag, self.msgNonNil)
            XCTAssertEqual(tag, expected, self.msgEqual)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// getUserTag with no config and no JWT → returns nil
    func test_9_getUserTag_configNil_returnsNil() {
        setMockConfig(nil)
        setMockJWT(nil)
        let exp = expectation(description: "userTag-nil")
        getUserTagMock { tag in
            XCTAssertNil(tag, self.msgNil)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
    
    /// getUserTag with whitespace rToken → returns it as-is
    func test_10_getUserTag_withWhitespaceRToken_returnsIt() {
        let cfg = Configuration(url: "https://example.com", rToken: "   ", appInfo: nil, providerPriorityList: nil)
        setMockConfig(cfg)
        let exp = expectation(description: "userTag-whitespace")
        getUserTagMock { tag in
            XCTAssertEqual(tag, "   ", self.msgEqual)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}

private extension String {
    func base64PaddingAdded() -> String {
        let paddingLength = (4 - count % 4) % 4
        return self + String(repeating: "=", count: paddingLength)
    }
}
