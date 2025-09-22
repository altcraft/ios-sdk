//
//  MockURLSession.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
@testable import Altcraft

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

public final class MockURLSession: URLSessioning {
    public enum ResultCase {
        case success(Data)    // data to “download”
        case failure(Error)   // simulated error
    }

    private let result: ResultCase
    private let statusCode: Int

    public init(result: ResultCase, statusCode: Int = 200) {
        self.result = result
        self.statusCode = statusCode
    }

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
