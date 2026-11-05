//
//  MockURLSession.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
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

// MARK: - Abstractions

public protocol URLSessionDownloadTasking {
    func resume()
}

public protocol URLSessioning {
    @discardableResult
    func makeDownloadTask(
        with url: URL,
        completionHandler: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void
    ) -> URLSessionDownloadTasking
}

// MARK: - Production wiring

extension URLSessionDownloadTask: URLSessionDownloadTasking {}

extension URLSession: URLSessioning {
    @discardableResult
    public func makeDownloadTask(
        with url: URL,
        completionHandler: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void
    ) -> URLSessionDownloadTasking {
        // This calls the native URLSession API (no recursion)
        return self.downloadTask(with: url, completionHandler: completionHandler)
    }
}

// MARK: - Test mock

/// URL session mock returning canned responses.
public final class MockURLSession: URLSessioning {
    /// Response scenario selector for the mock.
    public enum ResultCase {
        case success(Data)
        case failure(Error)
    }

    private let result: ResultCase
    private let statusCode: Int

    public init(result: ResultCase, statusCode: Int = 200) {
        self.result = result
        self.statusCode = statusCode
    }

    /// Download task mock.
    private final class MockTask: URLSessionDownloadTasking {
        private let work: () -> Void
        init(work: @escaping () -> Void) { self.work = work }
        func resume() { work() }
    }

    @discardableResult
    public func makeDownloadTask(
        with url: URL,
        completionHandler: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void
    ) -> URLSessionDownloadTasking {
        return MockTask { [result, statusCode] in
            let resp = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)

            switch result {
            case .success(let data):
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                try? data.write(to: tempURL)
                completionHandler(tempURL, resp, nil)

            case .failure(let error):
                completionHandler(nil, resp, error)
            }
        }
    }
}
